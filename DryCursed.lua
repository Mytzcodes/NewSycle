local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Print posisi sekali
print("Posisi sekarang:", rootPart.Position)
-- Output contoh: Vector3(120.5, 10.0, 0.0)
