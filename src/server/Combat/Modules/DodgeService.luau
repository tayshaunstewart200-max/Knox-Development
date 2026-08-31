local DodgeService = {}

local CombatStateManager = require(game:GetService("ReplicatedStorage").SharedModules.CombatStateManager)

local CONFIG = {
	DodgeForce = 80,
	DodgeDuration = 0.6,
	IFrameDuration = 0.4,
	StaminaCost = 25,
	Cooldown = 0.8,
	UpwardBias = 0.15,
}

local dodgeData = {}

local function GetData(character)
	if not dodgeData[character] then
		dodgeData[character] = { onCooldown = false, cooldownTimer = nil }
	end
	return dodgeData[character]
end

local function CancelTimer(timer)
	if timer then pcall(task.cancel, timer) end
end

local function GetRoot(character)
	return character:FindFirstChild("HumanoidRootPart")
end

local function CalculateDodgeDirection(character, clientDirection)
	local root = GetRoot(character)
	if not root then return Vector3.new(0, 0, -1) end
	if clientDirection and clientDirection.Magnitude > 0.1 then
		return Vector3.new(clientDirection.X, 0, clientDirection.Z).Unit
	end
	local look = -root.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit
end

local function StartCooldown(character)
	local data = GetData(character)
	data.onCooldown = true
	CancelTimer(data.cooldownTimer)
	data.cooldownTimer = task.delay(CONFIG.Cooldown, function()
		data.onCooldown = false
		data.cooldownTimer = nil
	end)
end

local function BeginDodge(character, direction)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local root = GetRoot(character)
	if not root then return end

	CombatStateManager:Add(character, "Dodging", CONFIG.DodgeDuration)
	CombatStateManager:Add(character, "Invincible", CONFIG.IFrameDuration)

	root.AssemblyLinearVelocity = Vector3.new(
		direction.X * CONFIG.DodgeForce,
		CONFIG.UpwardBias * CONFIG.DodgeForce,
		direction.Z * CONFIG.DodgeForce
	)

	task.delay(CONFIG.DodgeDuration, function()
		if character and character.Parent then
			CombatStateManager:Remove(character, "Dodging")
		end
	end)
end

function DodgeService:Attempt(player, clientDirection)
	local character = player.Character
	if not character then return false end
	if not CombatStateManager:CanAct(character, "Dodge") then return false end

	local data = GetData(character)
	if data.onCooldown then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	local staminaFolder = character:FindFirstChild("Stamina")
	if staminaFolder then
		local stamina = staminaFolder:FindFirstChild("Value")
		if not stamina or stamina.Value < CONFIG.StaminaCost then return false end
		stamina.Value = math.max(0, stamina.Value - CONFIG.StaminaCost)
	end

	BeginDodge(character, CalculateDodgeDirection(character, clientDirection))
	StartCooldown(character)
	return true
end

function DodgeService:IsOnCooldown(character)
	if not character then return false end
	return GetData(character).onCooldown
end

function DodgeService:Cleanup(character)
	if not character then return end
	local data = dodgeData[character]
	if data then CancelTimer(data.cooldownTimer) end
	dodgeData[character] = nil
end

return DodgeService