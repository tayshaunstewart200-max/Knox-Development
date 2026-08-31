local SpeedController = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MovementConfig = require(script.Parent.MovementConfig)

local SPEED = MovementConfig.Speed
local player = Players.LocalPlayer

local abs = math.abs
local min = math.min

local currentSpeed = SPEED.Walk
local targetSpeed = SPEED.Walk
local connection = nil
local humanoid = nil

local function Lerp(a, b, t)
	return a + (b - a) * t
end

function SpeedController:Setup(character)
	humanoid = character:FindFirstChildOfClass("Humanoid")
	currentSpeed = SPEED.Walk
	targetSpeed = SPEED.Walk

	if connection then
		connection:Disconnect()
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		if not humanoid then return end
		local rate = (targetSpeed > currentSpeed and SPEED.Acceleration or SPEED.Deceleration) * dt
		currentSpeed = Lerp(currentSpeed, targetSpeed, min(1, rate))
		if abs(currentSpeed - humanoid.WalkSpeed) > 0.1 then
			humanoid.WalkSpeed = currentSpeed
		end
	end)
end

function SpeedController:SetTarget(speedName, staminaNormalized)
	local base = SPEED[speedName] or SPEED.Walk
	local multiplier = player:GetAttribute("SpeedMultiplier") or 1

	-- Disabled is an explicit zero-speed state. It must not be modified by
	-- stamina depletion or other normal movement multipliers.
	if speedName == "Disabled" then
		targetSpeed = 0
		return
	end

	base = base * multiplier

	if staminaNormalized and staminaNormalized < 0.15 then
		base = Lerp(SPEED.Depleted, base, staminaNormalized / 0.15)
	end

	targetSpeed = base
end

function SpeedController:GetCurrent()
	return currentSpeed
end

function SpeedController:GetTarget()
	return targetSpeed
end

function SpeedController:Cleanup()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if humanoid then
		humanoid.WalkSpeed = SPEED.Walk
	end
	humanoid = nil
	currentSpeed = SPEED.Walk
	targetSpeed = SPEED.Walk
end

return SpeedController
