local MomentumController = {}

local RunService = game:GetService("RunService")
local MovementConfig = require(script.Parent.MovementConfig)
local MovementStateResolver = require(script.Parent.MovementStateResolver)
local CombatStateManager = require(script.Parent.Parent.Parent.SharedModules.CombatStateManager)

local CONFIG = MovementConfig.Momentum

local connection = nil
local humanoid = nil
local hrp = nil
local character = nil

local function GetHorizontal(vector)
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	if horizontal.Magnitude < CONFIG.MinTurnThreshold then
		return nil
	end
	return horizontal.Unit
end

function MomentumController:Setup(newCharacter)
	self:Cleanup()

	character = newCharacter
	humanoid = newCharacter:FindFirstChildOfClass("Humanoid")
	hrp = newCharacter:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		character = nil
		return
	end

	-- Rotation is owned exclusively by this controller during exploration.
	humanoid.AutoRotate = false

	connection = RunService.Heartbeat:Connect(function(dt)
		if not character or not humanoid or not hrp or humanoid.Health <= 0 then
			return
		end

		local policy = MovementStateResolver:Resolve(character, CombatStateManager)
		if not policy.CanRotate then
			return
		end

		local moveDirection = GetHorizontal(humanoid.MoveDirection)
		if not moveDirection then
			return
		end

		local currentLook = GetHorizontal(hrp.CFrame.LookVector)
		if not currentLook then
			return
		end

		-- Exploration rule: forward/side movement drives facing, but a
		-- predominantly backward input does not force a 180-degree turn.
		local forwardDot = currentLook:Dot(moveDirection)
		if forwardDot < -0.35 then
			return
		end

		local targetCFrame = CFrame.lookAt(hrp.Position, hrp.Position + moveDirection)
		local alpha = 1 - math.exp(-CONFIG.TurnSpeed * dt)
		hrp.CFrame = hrp.CFrame:Lerp(targetCFrame, alpha)
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
	character = nil
end

return MomentumController
