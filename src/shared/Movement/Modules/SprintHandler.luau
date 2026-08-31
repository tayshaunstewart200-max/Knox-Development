local SprintHandler = {}

local DEFAULT_SPEED = 16
local SPRINT_SPEED = 28

local StateManager = require(game:GetService("ReplicatedStorage").SharedModules.StateManager)

function SprintHandler:Start(character, staminaHandler)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if staminaHandler:IsDepleted() then return end
	if StateManager:HasState(character, "Stunned") then return end
	if StateManager:HasState(character, "Dead") then return end

	humanoid.WalkSpeed = SPRINT_SPEED
	staminaHandler:StartDrain()
	StateManager:AddState(character, "Sprinting")
end

function SprintHandler:Stop(character, staminaHandler)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.WalkSpeed = DEFAULT_SPEED
	staminaHandler:StopDrain()
	StateManager:RemoveState(character, "Sprinting")
end

return SprintHandler