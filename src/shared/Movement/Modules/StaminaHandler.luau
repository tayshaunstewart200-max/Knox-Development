local StaminaHandler = {}

local MAX_STAMINA = 1000
local SPRINT_DRAIN = 20
local REGEN_RATE = 100
local REGEN_DELAY = 1

local stamina = MAX_STAMINA
local regenTimer = 0
local isDraining = false
local connection = nil

local RunService = game:GetService("RunService")

function StaminaHandler:StartDrain(rate)
	isDraining = true
	regenTimer = REGEN_DELAY
end

function StaminaHandler:StopDrain()
	isDraining = false
end

function StaminaHandler:Consume(amount)
	if stamina < amount then return false end
	stamina = math.max(0, stamina - amount)
	regenTimer = REGEN_DELAY
	return true
end

function StaminaHandler:Get()
	return stamina
end

function StaminaHandler:GetMax()
	return MAX_STAMINA
end

function StaminaHandler:IsDepleted()
	return stamina <= 0
end

function StaminaHandler:Start()
	if connection then return end
	connection = RunService.Heartbeat:Connect(function(dt)
		if isDraining then
			stamina = math.max(0, stamina - SPRINT_DRAIN * dt)
		else
			if regenTimer > 0 then
				regenTimer = regenTimer - dt
			else
				stamina = math.min(MAX_STAMINA, stamina + REGEN_RATE * dt)
			end
		end
	end)
end

function StaminaHandler:Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return StaminaHandler