local ParryService = {}

local Players = game:GetService("Players")
local CombatStateManager = require(game:GetService("ReplicatedStorage").SharedModules.CombatStateManager)

local CONFIG = {
	ParryCooldown      = 1.0,
	StunDuration       = 1.5,
	GuardBreakDuration = 3.0,
	ParryStateDuration = 0.35,
}

local parryData = {}

local ClashService = {
	CheckClash = function(self, attackerCharacter, defenderCharacter)
		return false
	end
}

local function GetData(character)
	if not parryData[character] then
		parryData[character] = { onCooldown = false, cooldownTimer = nil }
	end
	return parryData[character]
end

local function CancelTimer(timer)
	if timer then pcall(task.cancel, timer) end
end

local function StartCooldown(character)
	local data = GetData(character)
	data.onCooldown = true
	CancelTimer(data.cooldownTimer)
	data.cooldownTimer = task.delay(CONFIG.ParryCooldown, function()
		if parryData[character] then
			parryData[character].onCooldown = false
			parryData[character].cooldownTimer = nil
		end
	end)
end

function ParryService:Attempt(character)
	if not character then return false end
	if not CombatStateManager:CanAct(character, "Parry") then return false end
	local data = GetData(character)
	if data.onCooldown then return false end
	CombatStateManager:Add(character, "Parrying", CONFIG.ParryStateDuration)
	StartCooldown(character)
	return true
end

function ParryService:CheckParry(attackerCharacter, defenderCharacter)
	if not attackerCharacter or not defenderCharacter then return false end
	if not CombatStateManager:Has(defenderCharacter, "Parrying") then return false end
	if ClashService:CheckClash(attackerCharacter, defenderCharacter) then return false end
	CombatStateManager:Add(attackerCharacter, "Stunned", CONFIG.StunDuration)
	CombatStateManager:Add(attackerCharacter, "GuardBreak", CONFIG.GuardBreakDuration)
	CombatStateManager:Remove(attackerCharacter, "Attacking")
	CombatStateManager:Remove(defenderCharacter, "Parrying")
	return true
end

function ParryService:IsOnCooldown(character)
	if not character then return false end
	return GetData(character).onCooldown
end

function ParryService:Cleanup(character)
	if not character then return end
	local data = parryData[character]
	if data then CancelTimer(data.cooldownTimer) end
	parryData[character] = nil
end

Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	if character then
		ParryService:Cleanup(character)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function(character)
		ParryService:Cleanup(character)
	end)
end)

return ParryService