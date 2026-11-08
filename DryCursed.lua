print(2)
task.wait(3)

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

warn("Posisi sekarang: " .. tostring(rootPart.Position))
