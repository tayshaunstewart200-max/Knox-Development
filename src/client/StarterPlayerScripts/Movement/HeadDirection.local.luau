local players = game:GetService("Players")
local runService = game:GetService("RunService")

local player = players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local atan2 = math.atan2
local cfAngles = CFrame.Angles
local v3New = Vector3.new

local followMouse = false
local rotateCharacter = false
local smoothness = 0.25
local invSmoothness = 1 - smoothness

local connection

local function onCharacterAdded(character)
	if connection then
		connection:Disconnect()
	end

	local humanoid = character:WaitForChild("Humanoid")
	local head = character:WaitForChild("Head")
	local rootPart = character:WaitForChild("HumanoidRootPart")
	local torso = character:WaitForChild("Torso")
	local neck = torso:WaitForChild("Neck")
	local neckStart = neck.C0

	local currentAngleOffset = cfAngles(0, 0, 0)
	local currentRootCFrame = rootPart.CFrame

	humanoid.AutoRotate = not rotateCharacter

	connection = runService.RenderStepped:Connect(function(delta)
		local mouseHit = (followMouse or rotateCharacter) and mouse.Hit.Position
		local target = followMouse and mouseHit or camera.CFrame.Position
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

		local targetAngleOffset = cfAngles(followMouse and angle * 0.6 or -angle * 0.6, 0, sideOffset)
		currentAngleOffset = currentAngleOffset:Lerp(targetAngleOffset, alpha)
		neck.C0 = neckStart * currentAngleOffset

		if rotateCharacter then
			local targetRootCFrame = CFrame.new(rootPart.Position, v3New(mouseHit.X, rootPart.Position.Y, mouseHit.Z))
			currentRootCFrame = currentRootCFrame:Lerp(targetRootCFrame, alpha)
			rootPart.CFrame = currentRootCFrame
		end
	end)
end

player.CharacterRemoving:Connect(function()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end)

player.CharacterAdded:Connect(onCharacterAdded)

if player.Character then
	onCharacterAdded(player.Character)
end