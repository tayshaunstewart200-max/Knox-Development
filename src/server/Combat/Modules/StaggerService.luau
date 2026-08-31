local StaggerService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatStateManager = require(ReplicatedStorage.SharedModules.CombatStateManager)
local KnockbackService   = require(script.Parent.KnockbackService)
local StaggerRemote      = ReplicatedStorage.Remotes.Combat.Stagger

local CONFIG = {
	StaggerDuration = 0.8,
}

local function GetHumanoid(character)
	return character:FindFirstChildOfClass("Humanoid")
end

local function GetPlayer(character)
	return Players:GetPlayerFromCharacter(character)
end

function StaggerService:Apply(attackerCharacter, targetCharacter, knockbackType)
	if not attackerCharacter or not targetCharacter then return end
	if CombatStateManager:Has(targetCharacter, "Dead") then return end
	if CombatStateManager:Has(targetCharacter, "Stunned") then return end

	CombatStateManager:Add(targetCharacter, "Stunned", CONFIG.StaggerDuration)

	if knockbackType then
		KnockbackService:Apply(attackerCharacter, targetCharacter, knockbackType)
	end

	local player = GetPlayer(targetCharacter)
	if player then
		StaggerRemote:FireClient(player, "Stagger", CONFIG.StaggerDuration)
	end
end

function StaggerService:ApplyDeath(attackerCharacter, targetCharacter)
	if not targetCharacter then return end

	CombatStateManager:Add(targetCharacter, "Dead")

	if attackerCharacter then
		KnockbackService:Apply(attackerCharacter, targetCharacter, "Finisher")
	end

	local player = GetPlayer(targetCharacter)
	if player then
		StaggerRemote:FireClient(player, "Death", 0)
	end

	task.delay(3, function()
		if targetCharacter and targetCharacter.Parent then
			local humanoid = GetHumanoid(targetCharacter)
			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Dead)
			end
		end
	end)
end

return StaggerService