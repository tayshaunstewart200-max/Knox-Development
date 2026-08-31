-- MomentumController
local MomentumController = {}

local RunService = game:GetService("RunService")
local MovementConfig = require(script.Parent.MovementConfig)

local CONFIG = MovementConfig.Momentum
local atan2 = math.atan2
local sin = math.sin
local cos = math.cos
local min = math.min
local cfNew = CFrame.new
local cfAngles = CFrame.Angles

local connection = nil
local humanoid = nil
local hrp = nil

function MomentumController:Setup(character)
	humanoid = character:FindFirstChildOfClass("Humanoid")
	hrp = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end

	humanoid.AutoRotate = false

	if connection then
		connection:Disconnect()
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		if not hrp then return end
		local moveDir = humanoid.MoveDirection
		if moveDir.Magnitude < CONFIG.MinTurnThreshold then return end

		local targetAngle = atan2(-moveDir.X, -moveDir.Z)
		local lookVector = hrp.CFrame.LookVector
		local currentAngle = atan2(-lookVector.X, -lookVector.Z)
		local diff = atan2(sin(targetAngle - currentAngle), cos(targetAngle - currentAngle))

		hrp.CFrame = cfNew(hrp.Position) * cfAngles(0, currentAngle + diff * min(1, CONFIG.TurnSpeed * dt), 0)
	end)
end

function MomentumController:Cleanup()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if humanoid then
		humanoid.AutoRotate = true
	end
	humanoid = nil
	hrp = nil
end

return MomentumController