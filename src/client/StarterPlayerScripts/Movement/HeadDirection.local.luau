local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CFrameAngles = CFrame.Angles
local atan2 = math.atan2

local smoothness = 0.25
local invSmoothness = 1 - smoothness

local connection

local function Cleanup()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

local function OnCharacterAdded(character)
	Cleanup()

	local head = character:WaitForChild("Head")
	local torso = character:WaitForChild("Torso")
	local neck = torso:WaitForChild("Neck")
	local neckStart = neck.C0

	local currentAngleOffset = CFrameAngles(0, 0, 0)

	connection = RunService.RenderStepped:Connect(function(delta)
		if not head.Parent or not torso.Parent or not neck.Parent then
			return
		end

		local target = camera.CFrame.Position
		local headPos = head.Position
		local diff = headPos - target
		local distance = diff.Magnitude

		local alpha = 1 - invSmoothness ^ (delta * 60)
		local angle = 0
		local sideOffset = 0

		if distance > 0.001 then
			angle = atan2(headPos.Y - target.Y, distance)
			sideOffset = (diff.Unit:Cross(torso.CFrame.LookVector)).Y
		end

		local targetAngleOffset = CFrameAngles(-angle * 0.6, 0, sideOffset)
		currentAngleOffset = currentAngleOffset:Lerp(targetAngleOffset, alpha)
		neck.C0 = neckStart * currentAngleOffset
	end)
end

player.CharacterRemoving:Connect(Cleanup)
player.CharacterAdded:Connect(OnCharacterAdded)

if player.Character then
	OnCharacterAdded(player.Character)
end
