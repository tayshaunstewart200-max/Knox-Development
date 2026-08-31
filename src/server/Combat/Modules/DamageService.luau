local DamageService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatStateManager = require(ReplicatedStorage.SharedModules.CombatStateManager)
local ParryService = require(script.Parent.ParryService)
local ProfileService = require(script.Parent.Parent.Parent.Progression.ProfileService)
local StatBonusService = require(script.Parent.Parent.Parent.Progression.StatBonusService)

local CONFIG = {
	BaseDamage = 65,
	CritMultiplier = 1.8,
	MinDamage = 1,
	MaxDamage = 9999,
	LevelScaling = 0.1,
	ComboMultipliers = {1.0, 1.2, 1.5},
	DefenseScaling = 100,
	ContributionThreshold = 0.20,
}

local AntiCheat = {
	LogSuspicious = function(self, playerName, reason, data)
		warn(string.format("[AntiCheat] %s | Player: %s | Data: %s", reason, tostring(playerName), tostring(data)))
	end,
	ValidateDamageRequest = function(self, attackerCharacter, targetCharacter, damage)
		return true
	end,
}

local function GetStat(character, statName, default)
	local stats = character:FindFirstChild("Stats")
	if not stats then return default end
	local stat = stats:FindFirstChild(statName)
	if not stat then return default end
	return stat.Value
end

local function GetPlayerName(character)
	local player = Players:GetPlayerFromCharacter(character)
	return player and player.Name or "Unknown"
end

local function GetDamageMultiplier(attackerCharacter)
	local player = Players:GetPlayerFromCharacter(attackerCharacter)
	if not player then
		return 1
	end
	local profile = ProfileService.GetProfile(player)
	if not profile then
		return 1
	end
	return StatBonusService.GetDamageMultiplier(profile.Data)
end

local function CalculateBase(attackerCharacter, comboStep)
	local attack = GetStat(attackerCharacter, "Attack", 10)
	local level = GetStat(attackerCharacter, "Level", 1)
	local comboMult = CONFIG.ComboMultipliers[comboStep] or CONFIG.ComboMultipliers[1]
	local levelBonus = 1 + (level - 1) * CONFIG.LevelScaling
	local rankBonus = GetDamageMultiplier(attackerCharacter)
	return CONFIG.BaseDamage + (attack * comboMult * levelBonus * rankBonus)
end

local function ApplyDefense(damage, targetCharacter)
	local defense = GetStat(targetCharacter, "Defense", 0)
	local reduction = defense / (defense + CONFIG.DefenseScaling)
	return damage * (1 - reduction)
end

local function RollCrit(attackerCharacter)
	local critChance = GetStat(attackerCharacter, "CritChance", 5)
	return math.random(1, 100) <= critChance
end

local function SanitizeDamage(damage)
	if type(damage) ~= "number" or damage ~= damage then return CONFIG.MinDamage end
	if damage == math.huge or damage == -math.huge then return CONFIG.MinDamage end
	return math.clamp(math.floor(damage), CONFIG.MinDamage, CONFIG.MaxDamage)
end

local function IsQuestNpc(character)
	local worldFolder = workspace:FindFirstChild("World")
	if not worldFolder then return false end
	local questNpcsFolder = worldFolder:FindFirstChild("QuestNpcs")
	if not questNpcsFolder then return false end
	return character:IsDescendantOf(questNpcsFolder)
end

local function ValidateRequest(attackerCharacter, targetCharacter, damage)
	if not attackerCharacter or not targetCharacter then return false, "invalid characters" end
	if IsQuestNpc(targetCharacter) then return false, "target is quest npc" end
	if CombatStateManager:Has(targetCharacter, "Invincible") then return false, "target invincible" end
	if CombatStateManager:Has(targetCharacter, "Dead") then return false, "target dead" end
	if CombatStateManager:Has(targetCharacter, "Parrying") then return false, "target parrying" end

	local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then return false, "target has no health" end

	if damage < CONFIG.MinDamage or damage > CONFIG.MaxDamage then
		AntiCheat:LogSuspicious(GetPlayerName(attackerCharacter), "damage out of range", damage)
		return false, "damage out of range"
	end

	if not AntiCheat:ValidateDamageRequest(attackerCharacter, targetCharacter, damage) then
		AntiCheat:LogSuspicious(GetPlayerName(attackerCharacter), "anticheat rejected", damage)
		return false, "anticheat rejected"
	end

	return true
end

local function HandleDeath(targetCharacter, targetHumanoid)
	if targetHumanoid.Health <= 0 and not CombatStateManager:Has(targetCharacter, "Dead") then
		CombatStateManager:Add(targetCharacter, "Dead")
	end
end

local function TrackContribution(attackerCharacter, targetHumanoid, damage)
	local attackerPlayer = Players:GetPlayerFromCharacter(attackerCharacter)
	if not attackerPlayer then
		return
	end

	local attributeKey = "DmgContrib_" .. tostring(attackerPlayer.UserId)
	local existing = targetHumanoid:GetAttribute(attributeKey) or 0
	local maxHealth = targetHumanoid.MaxHealth

	local updated = math.min(existing + damage, maxHealth)
	targetHumanoid:SetAttribute(attributeKey, updated)
end

function DamageService:Calculate(attackerCharacter, targetCharacter, comboStep)
	if not attackerCharacter or not targetCharacter then return CONFIG.MinDamage, false end
	local base = CalculateBase(attackerCharacter, comboStep)
	local afterDefense = ApplyDefense(base, targetCharacter)
	local isCrit = RollCrit(attackerCharacter)
	local final = isCrit and afterDefense * CONFIG.CritMultiplier or afterDefense
	return SanitizeDamage(final), isCrit
end

function DamageService:Apply(attackerCharacter, targetCharacter, comboStep)
	local damage, isCrit = self:Calculate(attackerCharacter, targetCharacter, comboStep)

	local valid, reason = ValidateRequest(attackerCharacter, targetCharacter, damage)
	if not valid then return nil, nil, reason end

	if ParryService:CheckParry(attackerCharacter, targetCharacter) then
		return 0, false, "parried"
	end

	local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid then return nil, nil, "no humanoid" end

	targetHumanoid:TakeDamage(damage)
	TrackContribution(attackerCharacter, targetHumanoid, damage)
	HandleDeath(targetCharacter, targetHumanoid)

	return damage, isCrit, "hit"
end

function DamageService:ApplyRaw(targetCharacter, damage)
	if not targetCharacter then return end
	if IsQuestNpc(targetCharacter) then return end
	if CombatStateManager:Has(targetCharacter, "Invincible") then return end
	if CombatStateManager:Has(targetCharacter, "Dead") then return end

	local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then return end

	targetHumanoid:TakeDamage(SanitizeDamage(damage))
	HandleDeath(targetCharacter, targetHumanoid)
end

return DamageService