--!strict
-- File: DryCursed_SDK.lua
-- Architecture: Luau (Roblox Client Environment) | Target: ByteNet Sandbox Game Framework
-- Dependencies: ReplicatedStorage.ByteNet, ReplicatedStorage.Shared, Packages (Promise, Signal, Janitor)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

export type TileCoord = { X: number, Y: number }
export type PacketSchema = { ID: number, Hex: string, Name: string, Struct: string }

local DryCursed = {}
DryCursed.__index = DryCursed
DryCursed.Version = "1.0.0-PROD"
DryCursed.Author = "Dry Cursed Community"

-- ============================================================================
-- 1. HEX-TO-ID REGISTRY (ABSTRAKSI PENUH DARI RAW HEX KE READABLE ID)
-- ============================================================================
DryCursed.PacketRegistry = {
	TILE_PUNCH      = { ID = 1,  Hex = "0x01", Name = "TilePunch",      Struct = "vec2_uint8" },
	TILE_PLACE      = { ID = 2,  Hex = "0x02", Name = "TilePlace",      Struct = "vec2_uint16" },
	TILE_WRENCH     = { ID = 3,  Hex = "0x03", Name = "TileWrench",     Struct = "vec2_uint8" },
	ITEM_DROP       = { ID = 4,  Hex = "0x04", Name = "ItemDrop",       Struct = "uint16_uint16" },
	ITEM_TRASH      = { ID = 5,  Hex = "0x05", Name = "ItemTrash",      Struct = "uint16_uint16" },
	ITEM_EQUIP      = { ID = 6,  Hex = "0x06", Name = "ItemEquip",      Struct = "uint16" },
	DOOR_ENTER      = { ID = 7,  Hex = "0x07", Name = "DoorEnter",      Struct = "vec2_string" },
	WORLD_WARP      = { ID = 8,  Hex = "0x08", Name = "WorldWarp",      Struct = "string" },
	VEND_BUY        = { ID = 9,  Hex = "0x09", Name = "VendBuy",        Struct = "vec2_uint16_uint32" },
	VEND_STOCK      = { ID = 10, Hex = "0x0A", Name = "VendStock",      Struct = "vec2_uint16" },
	PVEND_BUY       = { ID = 11, Hex = "0x0B", Name = "PVendBuy",       Struct = "vec2_uint16_uint32" },
	COMBINE_ITEMS   = { ID = 12, Hex = "0x0C", Name = "CombineItems",   Struct = "vec2_uint16_uint16_uint16" },
	SPLICE_SEEDS    = { ID = 13, Hex = "0x0D", Name = "SpliceSeeds",    Struct = "vec2_uint16_uint16" },
	TRADE_OFFER     = { ID = 14, Hex = "0x0E", Name = "TradeOffer",     Struct = "uint32_uint16_uint16" },
	TRADE_ACCEPT    = { ID = 15, Hex = "0x0F", Name = "TradeAccept",    Struct = "bool" },
	SURGERY_TOOL    = { ID = 16, Hex = "0x10", Name = "SurgeryTool",    Struct = "uint8" },
	AREA_LOCK_EDIT  = { ID = 17, Hex = "0x11", Name = "AreaLockEdit",   Struct = "vec2_uint8_bool" },
	SHOP_BUY_PACK   = { ID = 18, Hex = "0x12", Name = "ShopBuyPack",    Struct = "string" },
	REDEEM_CODE     = { ID = 19, Hex = "0x13", Name = "RedeemCode",     Struct = "string" },
	CHAT_SEND       = { ID = 20, Hex = "0x14", Name = "ChatSend",       Struct = "string" },
	COLLECT_OBJECT  = { ID = 21, Hex = "0x15", Name = "CollectObject",  Struct = "uint32" },
}

DryCursed.ReversePacketMap = {}
for key, data in pairs(DryCursed.PacketRegistry) do
	DryCursed.ReversePacketMap[data.ID] = key
	DryCursed.ReversePacketMap[data.Hex] = key
end

DryCursed.SurgeryTools = {
	SPONGE     = 1,
	SCALPEL    = 2,
	STITCHES   = 3,
	ANTIBIOTIC = 4,
	ANTISEPTIC = 5,
	ANESTHETIC = 6,
	LAB_KIT    = 7,
	PINS       = 8,
	CLAMP      = 9,
	TRANSFUSE  = 10,
	DEFIB      = 11,
	SPLINT     = 12,
}

-- ============================================================================
-- 2. INTERNAL MODULE RESOLVER & CACHE
-- ============================================================================
DryCursed.Modules = {
	ByteNet     = nil :: any,
	SharedNet   = nil :: any,
	ItemDB      = {} :: { [number]: any },
	ItemNameMap = {} :: { [string]: number },
	BlocksDB    = {} :: { [number]: any },
	ClothesDB   = {} :: { [number]: any },
	SpliceDB    = {} :: { [string]: number },
	CombineDB   = {} :: { [string]: number },
	WorldCodec  = nil :: any,
	Inventory   = nil :: any,
	Janitor     = nil :: any,
	Signal      = nil :: any,
	Promise     = nil :: any,
}

local function safeRequire(instance: Instance?): any
	if not instance or not instance:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, instance)
	return if ok then result else nil
end

function DryCursed:Init(): boolean
	local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 5)
	local packagesFolder = ReplicatedStorage:WaitForChild("Packages", 5)
	local byteNetModule = ReplicatedStorage:FindFirstChild("ByteNet")

	if byteNetModule then
		self.Modules.ByteNet = safeRequire(byteNetModule)
	end

	if packagesFolder then
		self.Modules.Janitor = safeRequire(packagesFolder:FindFirstChild("Janitor"))
		self.Modules.Signal = safeRequire(packagesFolder:FindFirstChild("Signal"))
		local indexFolder = packagesFolder:FindFirstChild("_Index")
		if indexFolder then
			for _, child in ipairs(indexFolder:GetDescendants()) do
				if child.Name == "promise" and child:IsA("ModuleScript") then
					self.Modules.Promise = safeRequire(child)
					break
				end
			end
		end
	end

	if sharedFolder then
		self.Modules.SharedNet  = safeRequire(sharedFolder:FindFirstChild("Net"))
		self.Modules.Inventory  = safeRequire(sharedFolder:FindFirstChild("Inventory"))
		self.Modules.WorldCodec = safeRequire(sharedFolder:FindFirstChild("WorldCodec"))

		local rawItems = safeRequire(sharedFolder:FindFirstChild("ItemDB"))
		if type(rawItems) == "table" then
			self.Modules.ItemDB = rawItems
			for id, info in pairs(rawItems) do
				local numId = tonumber(id) or info.id or info.ID
				local name = type(info) == "table" and (info.name or info.Name) or nil
				if numId and type(name) == "string" then
					self.Modules.ItemNameMap[string.lower(name)] = numId
				end
			end
		end

		local rawBlocks = safeRequire(sharedFolder:FindFirstChild("BlocksDB"))
		if type(rawBlocks) == "table" then
			self.Modules.BlocksDB = rawBlocks
			for id, info in pairs(rawBlocks) do
				local numId = tonumber(id) or (type(info) == "table" and (info.id or info.ID))
				local name = type(info) == "table" and (info.name or info.Name) or nil
				if numId and type(name) == "string" and not self.Modules.ItemNameMap[string.lower(name)] then
					self.Modules.ItemNameMap[string.lower(name)] = numId
				end
			end
		end

		local rawClothes = safeRequire(sharedFolder:FindFirstChild("ClothesDB"))
		if type(rawClothes) == "table" then
			self.Modules.ClothesDB = rawClothes
		end

		-- Dynamic Packet ID Binding dari ByteNet.namespaces.packetIDs jika tersedia
		if byteNetModule then
			local namespaces = byteNetModule:FindFirstChild("namespaces")
			local packetIDsMod = namespaces and namespaces:FindFirstChild("packetIDs")
			local runtimeIDs = safeRequire(packetIDsMod)
			if type(runtimeIDs) == "table" then
				for name, runtimeId in pairs(runtimeIDs) do
					for _, reg in pairs(self.PacketRegistry) do
						if string.lower(reg.Name) == string.lower(tostring(name)) and type(runtimeId) == "number" then
							reg.ID = runtimeId
							reg.Hex = string.format("0x%02X", runtimeId)
						end
					end
				end
			end
		end
	end

	return true
end

-- ============================================================================
-- 3. DATABASE & ITEM ID RESOLVER (NO-HEX USER INTERFACE)
-- ============================================================================
DryCursed.DB = {}

function DryCursed.DB.GetID(itemIdentifier: string | number): number
	if type(itemIdentifier) == "number" then
		return math.clamp(math.floor(itemIdentifier), 0, 65535)
	end
	local cleanName = string.lower(string.gsub(itemIdentifier, "^%s*(.-)%s*$", "%1"))
	if DryCursed.Modules.ItemNameMap[cleanName] then
		return DryCursed.Modules.ItemNameMap[cleanName]
	end
	for registeredName, id in pairs(DryCursed.Modules.ItemNameMap) do
		if string.find(registeredName, cleanName, 1, true) then
			return id
		end
	end
	return 0
end

function DryCursed.DB.GetSeedID(blockIdentifier: string | number): number
	local baseId = DryCursed.DB.GetID(blockIdentifier)
	if baseId == 0 then return 0 end
	local info = DryCursed.Modules.ItemDB[baseId] or DryCursed.Modules.BlocksDB[baseId]
	if type(info) == "table" and info.seedId then
		return info.seedId
	end
	return baseId + 1
end

function DryCursed.DB.GetInfo(itemIdentifier: string | number): { [string]: any }?
	local id = DryCursed.DB.GetID(itemIdentifier)
	return DryCursed.Modules.ItemDB[id] or DryCursed.Modules.BlocksDB[id] or DryCursed.Modules.ClothesDB[id]
end

-- ============================================================================
-- 4. BYTENET BUFFER COMPILER & DISPATCHER (INTERNAL ENGINE)
-- ============================================================================
DryCursed.Net = {}
DryCursed.Net._Remote = nil :: RemoteEvent?
DryCursed.Net._Listeners = {} :: { [string]: { (any) -> () } }

function DryCursed.Net._GetRemote(): RemoteEvent?
	if DryCursed.Net._Remote and DryCursed.Net._Remote.Parent then
		return DryCursed.Net._Remote
	end
	for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
		if inst:IsA("RemoteEvent") and (string.find(string.lower(inst.Name), "bytenet") or string.find(string.lower(inst.Name), "net")) then
			DryCursed.Net._Remote = inst
			return inst
		end
	end
	return nil
end

function DryCursed.Net.EncodePacket(actionKey: string | number, payload: { [string]: any }): buffer
	local schema: PacketSchema? = nil
	if type(actionKey) == "number" then
		local mappedKey = DryCursed.ReversePacketMap[actionKey]
		schema = mappedKey and DryCursed.PacketRegistry[mappedKey]
	else
		schema = DryCursed.PacketRegistry[actionKey] or DryCursed.PacketRegistry[DryCursed.ReversePacketMap[actionKey]]
	end

	local packetId = if schema then schema.ID else (tonumber(actionKey) or 0)
	local structType = if schema then schema.Struct else "raw"

	if structType == "vec2_uint8" then
		local buf = buffer.create(6)
		buffer.writeu8(buf, 0, packetId)
		buffer.writei16(buf, 1, math.clamp(payload.X or 0, -32768, 32767))
		buffer.writei16(buf, 3, math.clamp(payload.Y or 0, -32768, 32767))
		buffer.writeu8(buf, 5, math.clamp(payload.Value or 0, 0, 255))
		return buf

	elseif structType == "vec2_uint16" then
		local buf = buffer.create(7)
		buffer.writeu8(buf, 0, packetId)
		buffer.writei16(buf, 1, math.clamp(payload.X or 0, -32768, 32767))
		buffer.writei16(buf, 3, math.clamp(payload.Y or 0, -32768, 32767))
		buffer.writeu16(buf, 5, math.clamp(payload.ItemID or 0, 0, 65535))
		return buf

	elseif structType == "uint16_uint16" then
		local buf = buffer.create(5)
		buffer.writeu8(buf, 0, packetId)
		buffer.writeu16(buf, 1, math.clamp(payload.ItemID or 0, 0, 65535))
		buffer.writeu16(buf, 3, math.clamp(payload.Count or 1, 0, 65535))
		return buf

	elseif structType == "uint16" then
		local buf = buffer.create(3)
		buffer.writeu8(buf, 0, packetId)
		buffer.writeu16(buf, 1, math.clamp(payload.ItemID or 0, 0, 65535))
		return buf

	elseif structType == "uint8" then
		local buf = buffer.create(2)
		buffer.writeu8(buf, 0, packetId)
		buffer.writeu8(buf, 1, math.clamp(payload.Value or 0, 0, 255))
		return buf

	elseif structType == "uint32" then
		local buf = buffer.create(5)
		buffer.writeu8(buf, 0, packetId)
		buffer.writeu32(buf, 1, math.clamp(payload.ObjectID or 0, 0, 4294967295))
		return buf

	elseif structType == "vec2_uint16_uint32" then
		local buf = buffer.create(11)
		buffer.writeu8(buf, 0, packetId)
		buffer.writei16(buf, 1, math.clamp(payload.X or 0, -32768, 32767))
		buffer.writei16(buf, 3, math.clamp(payload.Y or 0, -32768, 32767))
		buffer.writeu16(buf, 5, math.clamp(payload.Count or 1, 0, 65535))
		buffer.writeu32(buf, 7, math.clamp(payload.ExpectedPrice or 0, 0, 4294967295))
		return buf

	elseif structType == "vec2_uint16_uint16" then
		local buf = buffer.create(9)
		buffer.writeu8(buf, 0, packetId)
		buffer.writei16(buf, 1, math.clamp(payload.X or 0, -32768, 32767))
		buffer.writei16(buf, 3, math.clamp(payload.Y or 0, -32768, 32767))
		buffer.writeu16(buf, 5, math.clamp(payload.SeedA or 0, 0, 65535))
		buffer.writeu16(buf, 7, math.clamp(payload.SeedB or 0, 0, 65535))
		return buf

	elseif structType == "vec2_uint16_uint16_uint16" then
		local buf = buffer.create(11)
		buffer.writeu8(buf, 0, packetId)
		buffer.writei16(buf, 1, math.clamp(payload.X or 0, -32768, 32767))
		buffer.writei16(buf, 3, math.clamp(payload.Y or 0, -32768, 32767))
		buffer.writeu16(buf, 5, math.clamp(payload.ItemA or 0, 0, 65535))
		buffer.writeu16(buf, 7, math.clamp(payload.ItemB or 0, 0, 65535))
		buffer.writeu16(buf, 9, math.clamp(payload.ItemC or 0, 0, 65535))
		return buf

	elseif structType == "string" then
		local str = tostring(payload.Text or "")
		local strLen = math.min(#str, 1024)
		local buf = buffer.create(3 + strLen)
		buffer.writeu8(buf, 0, packetId)
		buffer.writeu16(buf, 1, strLen)
		buffer.writestring(buf, 3, str, strLen)
		return buf
	end

	local fallback = buffer.create(1)
	buffer.writeu8(fallback, 0, packetId)
	return fallback
end

function DryCursed.Net.Send(actionKey: string | number, payload: { [string]: any }): boolean
	-- Prioritas 1: Gunakan Shared.Net native function jika tersedia
	local sharedNet = DryCursed.Modules.SharedNet
	local schema = DryCursed.PacketRegistry[tostring(actionKey)]
	if type(sharedNet) == "table" and schema and type(sharedNet[schema.Name]) == "function" then
		local ok = pcall(sharedNet[schema.Name], payload)
		if ok then return true end
	end

	-- Prioritas 2: Gunakan ByteNet Buffer Writer & Remote Dispatcher
	local packetBuffer = DryCursed.Net.EncodePacket(actionKey, payload)
	local remote = DryCursed.Net._GetRemote()
	if remote then
		remote:FireServer(packetBuffer)
		return true
	end
	return false
end

-- ============================================================================
-- 5. WORLD, GRID & TILE CONTROLLER
-- ============================================================================
DryCursed.World = {}
DryCursed.World.TileSize = 3 -- Ukuran standar stud per tile

function DryCursed.World.GetPlayerTile(): TileCoord
	local character = LocalPlayer and LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return { X = 0, Y = 0 }
	end
	local pos = rootPart.Position
	return {
		X = math.floor((pos.X / DryCursed.World.TileSize) + 0.5),
		Y = math.floor((pos.Y / DryCursed.World.TileSize) + 0.5),
	}
end

function DryCursed.World.Punch(relOrAbsX: number, relOrAbsY: number, isRelative: boolean?): boolean
	local targetX, targetY = relOrAbsX, relOrAbsY
	if isRelative then
		local base = DryCursed.World.GetPlayerTile()
		targetX = base.X + relOrAbsX
		targetY = base.Y + relOrAbsY
	end
	return DryCursed.Net.Send("TILE_PUNCH", { X = targetX, Y = targetY, Value = 1 })
end

function DryCursed.World.Place(relOrAbsX: number, relOrAbsY: number, itemIdentifier: string | number, isRelative: boolean?): boolean
	local itemId = DryCursed.DB.GetID(itemIdentifier)
	if itemId == 0 then return false end
	local targetX, targetY = relOrAbsX, relOrAbsY
	if isRelative then
		local base = DryCursed.World.GetPlayerTile()
		targetX = base.X + relOrAbsX
		targetY = base.Y + relOrAbsY
	end
	return DryCursed.Net.Send("TILE_PLACE", { X = targetX, Y = targetY, ItemID = itemId })
end

function DryCursed.World.Wrench(relOrAbsX: number, relOrAbsY: number, isRelative: boolean?): boolean
	local targetX, targetY = relOrAbsX, relOrAbsY
	if isRelative then
		local base = DryCursed.World.GetPlayerTile()
		targetX = base.X + relOrAbsX
		targetY = base.Y + relOrAbsY
	end
	return DryCursed.Net.Send("TILE_WRENCH", { X = targetX, Y = targetY, Value = 0 })
end

function DryCursed.World.Warp(worldName: string, doorId: string?): boolean
	local cleanWorld = string.upper(string.gsub(worldName, "%s+", ""))
	if doorId and #doorId > 0 then
		cleanWorld = cleanWorld .. ":" .. doorId
	end
	return DryCursed.Net.Send("WORLD_WARP", { Text = cleanWorld })
end

function DryCursed.World.CollectDroppedObject(objectUid: number): boolean
	return DryCursed.Net.Send("COLLECT_OBJECT", { ObjectID = objectUid })
end

-- ============================================================================
-- 6. INVENTORY, CRAFTING, VENDING & SURGERY CONTROLLERS
-- ============================================================================
DryCursed.Inventory = {}

function DryCursed.Inventory.GetCount(itemIdentifier: string | number): number
	local itemId = DryCursed.DB.GetID(itemIdentifier)
	local invMod = DryCursed.Modules.Inventory
	if type(invMod) == "table" then
		if type(invMod.GetItemCount) == "function" then
			local ok, count = pcall(invMod.GetItemCount, itemId)
			if ok and type(count) == "number" then return count end
		elseif type(invMod.Items) == "table" and invMod.Items[itemId] then
			return invMod.Items[itemId].Amount or invMod.Items[itemId].count or 0
		end
	end
	return 0
end

function DryCursed.Inventory.Drop(itemIdentifier: string | number, count: number?): boolean
	local itemId = DryCursed.DB.GetID(itemIdentifier)
	if itemId == 0 then return false end
	local dropAmount = count or DryCursed.Inventory.GetCount(itemId)
	return DryCursed.Net.Send("ITEM_DROP", { ItemID = itemId, Count = math.max(1, dropAmount) })
end

function DryCursed.Inventory.Trash(itemIdentifier: string | number, count: number?): boolean
	local itemId = DryCursed.DB.GetID(itemIdentifier)
	if itemId == 0 then return false end
	return DryCursed.Net.Send("ITEM_TRASH", { ItemID = itemId, Count = math.max(1, count or 1) })
end

function DryCursed.Inventory.Equip(itemIdentifier: string | number): boolean
	local itemId = DryCursed.DB.GetID(itemIdentifier)
	if itemId == 0 then return false end
	return DryCursed.Net.Send("ITEM_EQUIP", { ItemID = itemId })
end

DryCursed.Craft = {}

function DryCursed.Craft.Splice(tileX: number, tileY: number, seedA: string | number, seedB: string | number): boolean
	local idA = DryCursed.DB.GetID(seedA)
	local idB = DryCursed.DB.GetID(seedB)
	return DryCursed.Net.Send("SPLICE_SEEDS", { X = tileX, Y = tileY, SeedA = idA, SeedB = idB })
end

function DryCursed.Craft.Combine(tileX: number, tileY: number, itemA: string | number, itemB: string | number, itemC: string | number): boolean
	return DryCursed.Net.Send("COMBINE_ITEMS", {
		X = tileX,
		Y = tileY,
		ItemA = DryCursed.DB.GetID(itemA),
		ItemB = DryCursed.DB.GetID(itemB),
		ItemC = DryCursed.DB.GetID(itemC),
	})
end

DryCursed.Vend = {}

function DryCursed.Vend.Buy(tileX: number, tileY: number, count: number, expectedPrice: number, isPublicVend: boolean?): boolean
	local action = if isPublicVend then "PVEND_BUY" else "VEND_BUY"
	return DryCursed.Net.Send(action, {
		X = tileX,
		Y = tileY,
		Count = count,
		ExpectedPrice = expectedPrice,
	})
end

function DryCursed.Vend.Restock(tileX: number, tileY: number, itemIdentifier: string | number): boolean
	return DryCursed.Net.Send("VEND_STOCK", {
		X = tileX,
		Y = tileY,
		ItemID = DryCursed.DB.GetID(itemIdentifier),
	})
end

DryCursed.Surgery = {}

function DryCursed.Surgery.UseTool(toolNameOrId: string | number): boolean
	local toolId = if type(toolNameOrId) == "number"
		then toolNameOrId
		else (DryCursed.SurgeryTools[string.upper(toolNameOrId)] or 1)
	return DryCursed.Net.Send("SURGERY_TOOL", { Value = toolId })
end

-- ============================================================================
-- 7. CONTINUOUS ALGORITHM SCHEDULER (STATE MACHINE & LOOP RUNNER)
-- ============================================================================
DryCursed.Scheduler = {}
DryCursed.Scheduler._Tasks = {} :: { [string]: { Active: boolean, Interval: number, LastTick: number, Callback: (dt: number) -> () } }
DryCursed.Scheduler._Connection = nil :: RBXScriptConnection?

function DryCursed.Scheduler._EnsureMasterLoop()
	if DryCursed.Scheduler._Connection then return end
	DryCursed.Scheduler._Connection = RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		for taskName, taskData in pairs(DryCursed.Scheduler._Tasks) do
			if taskData.Active and (now - taskData.LastTick) >= taskData.Interval then
				taskData.LastTick = now
				local ok, err = pcall(taskData.Callback, dt)
				if not ok then
					warn(string.format("[DryCursed.Scheduler] Task '%s' error: %s", taskName, tostring(err)))
				end
			end
		end
	end)
end

function DryCursed.Scheduler.StartTask(taskName: string, intervalSeconds: number, callback: (dt: number) -> ())
	DryCursed.Scheduler._EnsureMasterLoop()
	DryCursed.Scheduler._Tasks[taskName] = {
		Active = true,
		Interval = math.max(0.015, intervalSeconds),
		LastTick = 0,
		Callback = callback,
	}
end

function DryCursed.Scheduler.StopTask(taskName: string)
	if DryCursed.Scheduler._Tasks[taskName] then
		DryCursed.Scheduler._Tasks[taskName].Active = false
		DryCursed.Scheduler._Tasks[taskName] = nil
	end
end

function DryCursed.Scheduler.StopAll()
	table.clear(DryCursed.Scheduler._Tasks)
	if DryCursed.Scheduler._Connection then
		DryCursed.Scheduler._Connection:Disconnect()
		DryCursed.Scheduler._Connection = nil
	end
end

-- Built-in Continuous PNB (Place & Break) Engine
function DryCursed.Scheduler.StartPNB(config: {
	Block: string | number,
	OffsetX: number?,
	OffsetY: number?,
	HitsPerBlock: number?,
	DelayMs: number?,
	AutoDropSeed: boolean?,
	SeedDropThreshold: number?,
})
	local blockId = DryCursed.DB.GetID(config.Block)
	local seedId = DryCursed.DB.GetSeedID(blockId)
	local offX = config.OffsetX or 0
	local offY = config.OffsetY or 1
	local hitsRequired = config.HitsPerBlock or 3
	local interval = (config.DelayMs or 160) / 1000
	local seedCap = config.SeedDropThreshold or 190

	local currentStage = "PLACE"
	local currentHits = 0

	DryCursed.Scheduler.StartTask("DryCursed_AutoPNB", interval, function()
		if config.AutoDropSeed and DryCursed.Inventory.GetCount(seedId) >= seedCap then
			DryCursed.Inventory.Drop(seedId)
			return
		end

		if currentStage == "PLACE" then
			DryCursed.World.Place(offX, offY, blockId, true)
			currentHits = 0
			currentStage = "PUNCH"
		elseif currentStage == "PUNCH" then
			DryCursed.World.Punch(offX, offY, true)
			currentHits += 1
			if currentHits >= hitsRequired then
				currentStage = "PLACE"
			end
		end
	end)
end

return DryCursed
