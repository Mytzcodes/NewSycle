print(1)
task.wait(2)
print(2)

local player = game.Players.LocalPlayer

-- Tunggu karakter dengan cara yang lebih aman
local character = player.Character
if not character then
    character = player.CharacterAdded:Wait()
end

print(3) -- cek apakah sampai sini

local rootPart = character:WaitForChild("HumanoidRootPart", 10)

if rootPart then
    warn("Posisi: " .. tostring(rootPart.Position))
else
    warn("RootPart tidak ditemukan!")
end
