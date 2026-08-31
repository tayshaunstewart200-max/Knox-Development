-- StaminaService
local StaminaService = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementConfig = require(script.Parent.MovementConfig)

local CONFIG = MovementConfig.Stamina
local abs = math.abs
local max = math.max
local min = math.min
local invMax = 1 / CONFIG.Max
local SYNC_THRESHOLD = 5

local stamina = CONFIG.Max
local isDraining = false
local regenTimer = 0
local connection = nil
local lastSyncedValue = CONFIG.Max

local StaminaSyncRemote = ReplicatedStorage.Remotes.Movement.StaminaSync

local function SyncToServer()
	if abs(stamina - lastSyncedValue) >= SYNC_THRESHOLD then
		StaminaSyncRemote:FireServer(stamina)
		lastSyncedValue = stamina
	end
end

function StaminaService:StartDrain()
	isDraining = true
	regenTimer = CONFIG.RegenDelay
end

function StaminaService:StopDrain()
	isDraining = false
end

function StaminaService:Consume(amount)
	if stamina < amount then return false end
	stamina = max(0, stamina - amount)
	regenTimer = CONFIG.RegenDelay
	SyncToServer()
	return true
end

function StaminaService:Get()
	return stamina
end

function StaminaService:GetMax()
	return CONFIG.Max
end

function StaminaService:GetNormalized()
	return stamina * invMax
end

function StaminaService:IsDepleted()
	return stamina <= CONFIG.DepletionThreshold
end

function StaminaService:IsFullyDepleted()
	return stamina <= 0
end

function StaminaService:Start()
	if connection then return end
	connection = RunService.Heartbeat:Connect(function(dt)
		if isDraining then
			stamina = max(0, stamina - CONFIG.SprintDrainRate * dt)
		else
			if regenTimer > 0 then
				regenTimer = max(0, regenTimer - dt)
			else
				stamina = min(CONFIG.Max, stamina + CONFIG.RegenRate * dt)
			end
		end
		SyncToServer()
	end)
end

function StaminaService:Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

function StaminaService:Cleanup()
	StaminaService:Stop()
	stamina = CONFIG.Max
	isDraining = false
	regenTimer = 0
	lastSyncedValue = CONFIG.Max
end

return StaminaService