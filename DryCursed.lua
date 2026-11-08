--!strict
-- GentaHax.lua
-- Target: Grow a Garden (Roblox) | ByteNet / Shared.Net Architecture
-- Luau Client Environment

-- ══════════════════════════════════════════════════════════════════
-- DAFTAR FUNGSI CEPAT
-- ══════════════════════════════════════════════════════════════════
--
-- getPos()                        → {x, y} posisi tile karakter
-- getPosRaw()                     → Vector3 posisi dunia karakter
-- tileFromWorld(wx, wy)           → {x, y} konversi dunia ke tile
-- worldFromTile(tx, ty)           → Vector3 konversi tile ke dunia
--
-- place(x, y, itemId)             → place tile di koordinat
-- placeRel(dx, dy, itemId)        → place relatif dari posisi sekarang
-- break_(x, y)                    → pukul / break tile di koordinat
-- breakRel(dx, dy)                → break relatif dari posisi sekarang
-- wrench(x, y)                    → wrench tile (buka menu tile)
-- harvest(x, y)                   → harvest provider (pohon, dll)
-- toggle(x, y)                    → toggle tile (switch, pintu, dll)
--
-- warp(worldName)                 → warp ke dunia lain
-- drop(itemId, count)             → drop item dari inventory
-- equip(itemId)                   → equip item di tangan
--
-- pnb(itemId, dx, dy, hits, ms)   → auto place & break loop
-- stopPNB()                       → hentikan loop pnb
--
-- farmArea(itemId,x1,y1,x2,y2,hits,ms) → farm area persegi
-- stopFarm()                      → hentikan farm area
--
-- stopAll()                       → hentikan semua loop
--
-- ══════════════════════════════════════════════════════════════════

local RS      = game:GetService("ReplicatedStorage")
local RunSvc  = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenSvc = game:GetService("TweenService")
local LP      = Players.LocalPlayer

-- ─── NET RESOLVER ─────────────────────────────────────────────────
local function getNet(): any
	return require(RS:WaitForChild("Shared"):WaitForChild("Net"))
end

-- ─── KONSTANTA GRID ───────────────────────────────────────────────
local TILE_SZ  = 2
local TILE_OFF = 0.5

-- ══════════════════════════════════════════════════════════════════
-- POS: POSISI & KONVERSI KOORDINAT
-- ══════════════════════════════════════════════════════════════════

local function getPosRaw(): Vector3
	local char = LP and LP.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then return hrp.Position end
	return Vector3.zero
end

local function tileFromWorld(wx: number, wy: number): { x: number, y: number }
	return {
		x = math.floor(wx / TILE_SZ + 0.5),
		y = math.floor(wy / TILE_SZ + 0.5),
	}
end

local function worldFromTile(tx: number, ty: number): Vector3
	return Vector3.new(tx * TILE_SZ + TILE_OFF, ty * TILE_SZ + TILE_OFF, 0)
end

local function getPos(): { x: number, y: number }
	local raw = getPosRaw()
	return tileFromWorld(raw.X, raw.Y)
end

-- ══════════════════════════════════════════════════════════════════
-- TILE ACTIONS
-- ══════════════════════════════════════════════════════════════════

local function place(x: number, y: number, itemId: number, layer: number?)
	getNet().tile.send({
		layer = layer or 1,
		x     = x,
		y     = y,
		id    = itemId,
		flip  = false,
	})
end

local function placeRel(dx: number, dy: number, itemId: number, layer: number?)
	local p = getPos()
	place(p.x + dx, p.y + dy, itemId, layer)
end

local function break_(x: number, y: number)
	getNet().act.send({
		kind = 6,
		x    = x + TILE_OFF,
		y    = y + TILE_OFF,
	})
end

local function breakRel(dx: number, dy: number)
	local p = getPos()
	break_(p.x + dx, p.y + dy)
end

local function wrench(x: number, y: number)
	getNet().act.send({
		kind = 1,
		x    = x + TILE_OFF,
		y    = y + TILE_OFF,
	})
end

local function harvest(x: number, y: number)
	getNet().harvest.send({ x = x, y = y })
end

local function toggle(x: number, y: number, layer: number?)
	getNet().toggle.send({
		layer = layer or 1,
		x     = x,
		y     = y,
	})
end

-- ══════════════════════════════════════════════════════════════════
-- WORLD & INVENTORY
-- ══════════════════════════════════════════════════════════════════

local function warp(worldName: string)
	local name = string.upper(string.gsub(worldName, "%s+", ""))
	getNet().tile.send({
		layer = 0, x = 0, y = 0, id = 0, flip = false, warp = name,
	})
end

local function drop(itemId: number, count: number?)
	getNet().drop.send({
		id    = itemId,
		count = math.max(1, count or 1),
	})
end

local function equip(itemId: number)
	getNet().wear.send({ hand = itemId, hat = nil })
end

-- ══════════════════════════════════════════════════════════════════
-- INTERNAL SCHEDULER
-- ══════════════════════════════════════════════════════════════════

local _tasks: { [string]: RBXScriptConnection } = {}

local function startLoop(name: string, intervalSec: number, fn: () -> ())
	if _tasks[name] then _tasks[name]:Disconnect() end
	local last = 0
	_tasks[name] = RunSvc.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last >= intervalSec then
			last = now
			local ok, err = pcall(fn)
			if not ok then warn("[GH] " .. name .. ": " .. tostring(err)) end
		end
	end)
end

local function stopLoop(name: string)
	if _tasks[name] then
		_tasks[name]:Disconnect()
		_tasks[name] = nil
	end
end

-- ══════════════════════════════════════════════════════════════════
-- PNB: PLACE AND BREAK LOOP
-- ══════════════════════════════════════════════════════════════════

local function pnb(itemId: number, dx: number?, dy: number?, hits: number?, ms: number?)
	local offX    = dx or 0
	local offY    = dy or 1
	local hitsReq = hits or 3
	local iv      = (ms or 160) / 1000
	local stage   = "PLACE"
	local hitCount = 0
	startLoop("pnb", iv, function()
		if stage == "PLACE" then
			placeRel(offX, offY, itemId)
			hitCount = 0
			stage    = "BREAK"
		else
			breakRel(offX, offY)
			hitCount += 1
			if hitCount >= hitsReq then stage = "PLACE" end
		end
	end)
end

local function stopPNB()
	stopLoop("pnb")
end

-- ══════════════════════════════════════════════════════════════════
-- FARM AREA
-- ══════════════════════════════════════════════════════════════════

local function farmArea(
	itemId: number,
	x1: number, y1: number,
	x2: number, y2: number,
	hits: number?,
	ms: number?
)
	local hitsReq = hits or 3
	local iv      = (ms or 160) / 1000
	local xs, xe  = math.min(x1,x2), math.max(x1,x2)
	local ys, ye  = math.min(y1,y2), math.max(y1,y2)

	local tiles: { { x: number, y: number } } = {}
	for ty = ys, ye do
		for tx = xs, xe do
			table.insert(tiles, { x = tx, y = ty })
		end
	end

	local idx      = 1
	local stage    = "PLACE"
	local hitCount = 0

	startLoop("farm", iv, function()
		if idx > #tiles then
			idx = 1 ; stage = "PLACE" ; hitCount = 0
		end
		local t = tiles[idx]
		if stage == "PLACE" then
			place(t.x, t.y, itemId)
			hitCount = 0 ; stage = "BREAK"
		else
			break_(t.x, t.y)
			hitCount += 1
			if hitCount >= hitsReq then idx += 1 ; stage = "PLACE" end
		end
	end)
end

local function stopFarm()
	stopLoop("farm")
end

local function stopAll()
	for name, conn in pairs(_tasks) do
		conn:Disconnect()
		_tasks[name] = nil
	end
end

-- ══════════════════════════════════════════════════════════════════
-- GUI VISUAL — HUMANOID PART BILLBOARD
-- ══════════════════════════════════════════════════════════════════
-- BillboardGui di atas kepala karakter, menampilkan:
--   · Nama player
--   · Posisi tile (X, Y) realtime
--   · Status task aktif (PNB / FARM / IDLE)
--   · Tombol toggle GUI (minimize / restore)
--   · Panel kontrol PNB dan Farm langsung di head
-- ══════════════════════════════════════════════════════════════════

local GUI_TAG  = "GH_HeadGui"
local ACCENT   = Color3.fromRGB(94, 234, 212)   -- teal
local BG_DARK  = Color3.fromRGB(10,  12,  20)
local BG_PANEL = Color3.fromRGB(15,  18,  30)
local TEXT_COL = Color3.fromRGB(220, 230, 255)
local RED_COL  = Color3.fromRGB(255, 80,  80)
local GREEN_COL= Color3.fromRGB(80,  255, 140)
local GRAY_COL = Color3.fromRGB(100, 110, 140)

-- Helper: buat instance dengan properti sekaligus
local function mk<T>(cls: string, props: { [string]: any }, parent: Instance?): T
	local inst = Instance.new(cls)
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	if parent then inst.Parent = parent end
	return inst :: any
end

-- Helper: button dengan hover effect
local function mkBtn(label: string, pos: UDim2, size: UDim2, col: Color3, parent: Instance): TextButton
	local btn = mk("TextButton", {
		Name            = label,
		Text            = label,
		Position        = pos,
		Size            = size,
		BackgroundColor3 = col,
		TextColor3      = Color3.fromRGB(10, 10, 10),
		TextScaled      = true,
		Font            = Enum.Font.GothamBold,
		BorderSizePixel = 0,
		AutoButtonColor = false,
	}, parent) :: TextButton

	local corner = mk("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
	_ = corner

	btn.MouseEnter:Connect(function()
		TweenSvc:Create(btn, TweenInfo.new(0.12), {
			BackgroundColor3 = col:Lerp(Color3.new(1,1,1), 0.18),
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenSvc:Create(btn, TweenInfo.new(0.12), {
			BackgroundColor3 = col,
		}):Play()
	end)

	return btn
end

local function buildGui()
	-- Hapus GUI lama jika ada
	local existing = LP.PlayerGui:FindFirstChild(GUI_TAG)
	if existing then existing:Destroy() end

	-- ── BILLBOARD DI ATAS KEPALA ────────────────────────────────
	local char = LP.Character or LP.CharacterAdded:Wait()
	local head = char:WaitForChild("Head") :: BasePart

	local bb = mk("BillboardGui", {
		Name           = GUI_TAG .. "_BB",
		Adornee        = head,
		Size           = UDim2.fromOffset(220, 90),
		StudsOffset    = Vector3.new(0, 2.8, 0),
		AlwaysOnTop    = true,
		ResetOnSpawn   = false,
		Active         = true,
	}, head) :: BillboardGui

	-- Background billboard
	local bbBg = mk("Frame", {
		Size            = UDim2.fromScale(1, 1),
		BackgroundColor3 = BG_DARK,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, bb) :: Frame
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, bbBg)
	mk("UIStroke", {
		Color     = ACCENT,
		Thickness = 1.4,
		Transparency = 0.3,
	}, bbBg)

	-- Label nama
	local nameLabel = mk("TextLabel", {
		Name       = "NameLabel",
		Text       = "⟐ " .. LP.Name,
		Size       = UDim2.new(1, 0, 0, 22),
		Position   = UDim2.fromOffset(0, 4),
		BackgroundTransparency = 1,
		TextColor3 = ACCENT,
		TextScaled = true,
		Font       = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, bbBg) :: TextLabel

	-- Label posisi
	local posLabel = mk("TextLabel", {
		Name       = "PosLabel",
		Text       = "Tile: (0, 0)",
		Size       = UDim2.new(1, -10, 0, 18),
		Position   = UDim2.new(0, 5, 0, 28),
		BackgroundTransparency = 1,
		TextColor3 = TEXT_COL,
		TextScaled = true,
		Font       = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, bbBg) :: TextLabel

	-- Label status
	local statusLabel = mk("TextLabel", {
		Name       = "StatusLabel",
		Text       = "● IDLE",
		Size       = UDim2.new(1, -10, 0, 18),
		Position   = UDim2.new(0, 5, 0, 48),
		BackgroundTransparency = 1,
		TextColor3 = GRAY_COL,
		TextScaled = true,
		Font       = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, bbBg) :: TextLabel

	-- Tombol minimize billboard
	local minBtn = mk("TextButton", {
		Name       = "MinBtn",
		Text       = "−",
		Size       = UDim2.fromOffset(20, 20),
		Position   = UDim2.new(1, -24, 0, 2),
		BackgroundColor3 = Color3.fromRGB(40,40,60),
		TextColor3 = TEXT_COL,
		TextScaled = true,
		Font       = Enum.Font.GothamBold,
		BorderSizePixel = 0,
		AutoButtonColor = false,
	}, bbBg) :: TextButton
	mk("UICorner", { CornerRadius = UDim.new(0, 5) }, minBtn)

	-- ── PANEL KONTROL UTAMA (ScreenGui) ─────────────────────────
	local sg = mk("ScreenGui", {
		Name          = GUI_TAG,
		ResetOnSpawn  = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, LP.PlayerGui) :: ScreenGui

	-- Frame utama — draggable
	local mainFrame = mk("Frame", {
		Name            = "Main",
		Size            = UDim2.fromOffset(300, 310),
		Position        = UDim2.fromOffset(20, 60),
		BackgroundColor3 = BG_DARK,
		BorderSizePixel = 0,
		Active          = true,
		Draggable       = true,
	}, sg) :: Frame
	mk("UICorner", { CornerRadius = UDim.new(0, 12) }, mainFrame)
	mk("UIStroke", {
		Color = ACCENT, Thickness = 1.5, Transparency = 0.2,
	}, mainFrame)

	-- Topbar
	local topbar = mk("Frame", {
		Name            = "Topbar",
		Size            = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Color3.fromRGB(20, 24, 42),
		BorderSizePixel = 0,
	}, mainFrame) :: Frame
	mk("UICorner", { CornerRadius = UDim.new(0, 12) }, topbar)

	mk("TextLabel", {
		Text       = "⟐  GentaHax",
		Size       = UDim2.new(1, -50, 1, 0),
		Position   = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		TextColor3 = ACCENT,
		Font       = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, topbar)

	-- Tombol close
	local closeBtn = mk("TextButton", {
		Text       = "✕",
		Size       = UDim2.fromOffset(28, 28),
		Position   = UDim2.new(1, -34, 0, 4),
		BackgroundColor3 = Color3.fromRGB(200, 50, 50),
		TextColor3 = Color3.new(1,1,1),
		Font       = Enum.Font.GothamBold,
		TextScaled = true,
		BorderSizePixel = 0,
		AutoButtonColor = false,
	}, topbar) :: TextButton
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, closeBtn)

	-- Content area
	local content = mk("Frame", {
		Name            = "Content",
		Size            = UDim2.new(1, -16, 1, -44),
		Position        = UDim2.fromOffset(8, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, mainFrame) :: Frame
	mk("UIListLayout", {
		Padding         = UDim.new(0, 8),
		FillDirection   = Enum.FillDirection.Vertical,
		SortOrder       = Enum.SortOrder.LayoutOrder,
	}, content)

	-- ── SECTION: INFO REALTIME ───────────────────────────────────
	local infoPanel = mk("Frame", {
		Name            = "InfoPanel",
		Size            = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = BG_PANEL,
		BorderSizePixel = 0,
		LayoutOrder     = 1,
	}, content) :: Frame
	mk("UICorner", { CornerRadius = UDim.new(0, 8) }, infoPanel)

	local infoPosLabel = mk("TextLabel", {
		Name       = "PosRT",
		Text       = "Tile  X: 0   Y: 0",
		Size       = UDim2.new(1, -10, 0, 22),
		Position   = UDim2.fromOffset(8, 4),
		BackgroundTransparency = 1,
		TextColor3 = TEXT_COL,
		Font       = Enum.Font.GothamMono,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, infoPanel) :: TextLabel

	local infoStatusLabel = mk("TextLabel", {
		Name       = "StatusRT",
		Text       = "Status: IDLE",
		Size       = UDim2.new(1, -10, 0, 22),
		Position   = UDim2.new(0, 8, 0, 28),
		BackgroundTransparency = 1,
		TextColor3 = GRAY_COL,
		Font       = Enum.Font.Gotham,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, infoPanel) :: TextLabel

	-- ── SECTION: PNB ────────────────────────────────────────────
	local pnbPanel = mk("Frame", {
		Name            = "PNBPanel",
		Size            = UDim2.new(1, 0, 0, 100),
		BackgroundColor3 = BG_PANEL,
		BorderSizePixel = 0,
		LayoutOrder     = 2,
	}, content) :: Frame
	mk("UICorner", { CornerRadius = UDim.new(0, 8) }, pnbPanel)

	mk("TextLabel", {
		Text       = "PNB — Place & Break",
		Size       = UDim2.new(1, -10, 0, 20),
		Position   = UDim2.fromOffset(8, 4),
		BackgroundTransparency = 1,
		TextColor3 = ACCENT,
		Font       = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, pnbPanel)

	-- Input ItemID
	local pnbItemBox = mk("TextBox", {
		Name            = "ItemID",
		PlaceholderText = "Item ID",
		Text            = "",
		Size            = UDim2.fromOffset(80, 24),
		Position        = UDim2.fromOffset(8, 28),
		BackgroundColor3 = Color3.fromRGB(25, 28, 48),
		TextColor3      = TEXT_COL,
		PlaceholderColor3 = GRAY_COL,
		Font            = Enum.Font.GothamMono,
		TextScaled      = true,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
	}, pnbPanel) :: TextBox
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, pnbItemBox)

	-- Input Hits
	local pnbHitsBox = mk("TextBox", {
		Name            = "Hits",
		PlaceholderText = "Hits",
		Text            = "3",
		Size            = UDim2.fromOffset(55, 24),
		Position        = UDim2.fromOffset(96, 28),
		BackgroundColor3 = Color3.fromRGB(25, 28, 48),
		TextColor3      = TEXT_COL,
		PlaceholderColor3 = GRAY_COL,
		Font            = Enum.Font.GothamMono,
		TextScaled      = true,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
	}, pnbPanel) :: TextBox
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, pnbHitsBox)

	-- Input Delay
	local pnbMsBox = mk("TextBox", {
		Name            = "Ms",
		PlaceholderText = "ms",
		Text            = "160",
		Size            = UDim2.fromOffset(55, 24),
		Position        = UDim2.fromOffset(159, 28),
		BackgroundColor3 = Color3.fromRGB(25, 28, 48),
		TextColor3      = TEXT_COL,
		PlaceholderColor3 = GRAY_COL,
		Font            = Enum.Font.GothamMono,
		TextScaled      = true,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
	}, pnbPanel) :: TextBox
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, pnbMsBox)

	local pnbStartBtn = mkBtn("▶ START PNB", UDim2.fromOffset(8, 60),  UDim2.fromOffset(126, 28), GREEN_COL, pnbPanel)
	local pnbStopBtn  = mkBtn("■ STOP PNB",  UDim2.fromOffset(142, 60), UDim2.fromOffset(120, 28), RED_COL,   pnbPanel)

	-- ── SECTION: FARM AREA ──────────────────────────────────────
	local farmPanel = mk("Frame", {
		Name            = "FarmPanel",
		Size            = UDim2.new(1, 0, 0, 108),
		BackgroundColor3 = BG_PANEL,
		BorderSizePixel = 0,
		LayoutOrder     = 3,
	}, content) :: Frame
	mk("UICorner", { CornerRadius = UDim.new(0, 8) }, farmPanel)

	mk("TextLabel", {
		Text       = "Farm Area  (x1 y1 → x2 y2)",
		Size       = UDim2.new(1, -10, 0, 20),
		Position   = UDim2.fromOffset(8, 4),
		BackgroundTransparency = 1,
		TextColor3 = ACCENT,
		Font       = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, farmPanel)

	-- Row 1: itemId, x1, y1
	local farmItemBox = mk("TextBox", {
		PlaceholderText = "Item ID",
		Text = "", Size = UDim2.fromOffset(80, 24),
		Position = UDim2.fromOffset(8, 28),
		BackgroundColor3 = Color3.fromRGB(25,28,48),
		TextColor3 = TEXT_COL, PlaceholderColor3 = GRAY_COL,
		Font = Enum.Font.GothamMono, TextScaled = true,
		BorderSizePixel = 0, ClearTextOnFocus = false,
	}, farmPanel) :: TextBox
	mk("UICorner", { CornerRadius = UDim.new(0,6) }, farmItemBox)

	local farmX1Box = mk("TextBox", {
		PlaceholderText = "x1", Text = "0",
		Size = UDim2.fromOffset(44, 24), Position = UDim2.fromOffset(96, 28),
		BackgroundColor3 = Color3.fromRGB(25,28,48),
		TextColor3 = TEXT_COL, PlaceholderColor3 = GRAY_COL,
		Font = Enum.Font.GothamMono, TextScaled = true,
		BorderSizePixel = 0, ClearTextOnFocus = false,
	}, farmPanel) :: TextBox
	mk("UICorner", { CornerRadius = UDim.new(0,6) }, farmX1Box)

	local farmY1Box = mk("TextBox", {
		PlaceholderText = "y1", Text = "0",
		Size = UDim2.fromOffset(44, 24), Position = UDim2.fromOffset(148, 28),
		BackgroundColor3 = Color3.fromRGB(25,28,48),
		TextColor3 = TEXT_COL, PlaceholderColor3 = GRAY_COL,
		Font = Enum.Font.GothamMono, TextScaled = true,
		BorderSizePixel = 0, ClearTextOnFocus = false,
	}, farmPanel) :: TextBox
	mk("UICorner", { CornerRadius = UDim.new(0,6) }, farmY1Box)

	-- Row 2: x2, y2
	local farmX2Box = mk("TextBox", {
		PlaceholderText = "x2", Text = "0",
		Size = UDim2.fromOffset(44, 24), Position = UDim2.fromOffset(8, 58),
		BackgroundColor3 = Color3.fromRGB(25,28,48),
		TextColor3 = TEXT_COL, PlaceholderColor3 = GRAY_COL,
		Font = Enum.Font.GothamMono, TextScaled = true,
		BorderSizePixel = 0, ClearTextOnFocus = false,
	}, farmPanel) :: TextBox
	mk("UICorner", { CornerRadius = UDim.new(0,6) }, farmX2Box)

	local farmY2Box = mk("TextBox", {
		PlaceholderText = "y2", Text = "0",
		Size = UDim2.fromOffset(44, 24), Position = UDim2.fromOffset(60, 58),
		BackgroundColor3 = Color3.fromRGB(25,28,48),
		TextColor3 = TEXT_COL, PlaceholderColor3 = GRAY_COL,
		Font = Enum.Font.GothamMono, TextScaled = true,
		BorderSizePixel = 0, ClearTextOnFocus = false,
	}, farmPanel) :: TextBox
	mk("UICorner", { CornerRadius = UDim.new(0,6) }, farmY2Box)

	local farmStartBtn = mkBtn("▶ FARM", UDim2.fromOffset(112, 55), UDim2.fromOffset(80, 30), GREEN_COL, farmPanel)
	local farmStopBtn  = mkBtn("■ STOP",  UDim2.fromOffset(200, 55), UDim2.fromOffset(68, 30), RED_COL,   farmPanel)

	-- ── REALTIME UPDATER ─────────────────────────────────────────
	local function getActiveStatus(): (string, Color3)
		local active = {}
		if _tasks["pnb"]  then table.insert(active, "PNB")  end
		if _tasks["farm"] then table.insert(active, "FARM") end
		if #active == 0 then
			return "● IDLE", GRAY_COL
		end
		return "● " .. table.concat(active, " + "), GREEN_COL
	end

	RunSvc.Heartbeat:Connect(function()
		local p = getPos()
		local px = tostring(p.x)
		local py = tostring(p.y)

		local statusTxt, statusCol = getActiveStatus()

		-- Billboard update
		posLabel.Text    = "Tile: (" .. px .. ", " .. py .. ")"
		statusLabel.Text = statusTxt
		statusLabel.TextColor3 = statusCol

		-- ScreenGui update
		infoPosLabel.Text = "Tile  X: " .. px .. "   Y: " .. py
		infoStatusLabel.Text = "Status: " .. (statusTxt:gsub("● ", ""))
		infoStatusLabel.TextColor3 = statusCol
	end)

	-- ── BUTTON LOGIC ─────────────────────────────────────────────
	pnbStartBtn.MouseButton1Click:Connect(function()
		local id    = tonumber(pnbItemBox.Text)
		local hits  = tonumber(pnbHitsBox.Text) or 3
		local ms    = tonumber(pnbMsBox.Text) or 160
		if not id then return end
		pnb(id, 0, 1, hits, ms)
	end)

	pnbStopBtn.MouseButton1Click:Connect(function()
		stopPNB()
	end)

	farmStartBtn.MouseButton1Click:Connect(function()
		local id = tonumber(farmItemBox.Text)
		local x1 = tonumber(farmX1Box.Text) or 0
		local y1 = tonumber(farmY1Box.Text) or 0
		local x2 = tonumber(farmX2Box.Text) or 0
		local y2 = tonumber(farmY2Box.Text) or 0
		if not id then return end
		farmArea(id, x1, y1, x2, y2, 3, 160)
	end)

	farmStopBtn.MouseButton1Click:Connect(function()
		stopFarm()
	end)

	-- Close / hide
	closeBtn.MouseButton1Click:Connect(function()
		TweenSvc:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromOffset(300, 0),
		}):Play()
		task.delay(0.2, function() mainFrame.Visible = false end)
	end)

	-- Billboard minimize toggle
	local bbVisible = true
	minBtn.MouseButton1Click:Connect(function()
		bbVisible = not bbVisible
		bbBg.Visible = bbVisible
		minBtn.Text = bbVisible and "−" or "+"
	end)

	-- Respawn rebuild
	LP.CharacterAdded:Connect(function()
		task.delay(2, buildGui)
	end)
end

-- ══════════════════════════════════════════════════════════════════
-- BOOT
-- ══════════════════════════════════════════════════════════════════

task.spawn(buildGui)

-- END
