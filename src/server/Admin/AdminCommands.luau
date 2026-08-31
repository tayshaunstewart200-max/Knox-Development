local Players = game:GetService("Players")

local ProfileService = require(script.Parent.Parent.Progression.ProfileService)
local ProgressionConfig = require(script.Parent.Parent.Progression.ProgressionConfig)
local ProgressionService = require(script.Parent.Parent.Progression.ProgressionService)
local RewardService = require(script.Parent.Parent.Progression.RewardService)
local LeaderstatsService = require(script.Parent.Parent.Progression.LeaderstatsService)
local StatBonusService = require(script.Parent.Parent.Progression.StatBonusService)

local AdminCommands = {}

local function FindPlayerByName(name)
	local lowerName = string.lower(name)
	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == lowerName then
			return player
		end
	end
	return nil
end

local function GetProfileOrWarn(admin, targetName)
	local target = FindPlayerByName(targetName)
	if target == nil then
		return nil, nil, "Player '" .. targetName .. "' not found"
	end

	local profile = ProfileService.GetProfile(target)
	if profile == nil then
		return nil, nil, "Profile for '" .. targetName .. "' is not loaded"
	end

	return target, profile, nil
end

function AdminCommands.SetLevel(admin, targetName, levelString)
	local target, profile, err = GetProfileOrWarn(admin, targetName)
	if err then
		return false, err
	end

	local level = tonumber(levelString)
	if level == nil or level < 1 or level ~= math.floor(level) then
		return false, "Level must be a positive whole number"
	end

	profile.Data.Level = level
	LeaderstatsService.UpdateLevel(target, level)

	return true, target.Name .. "'s level set to " .. level
end

local function ComputeCumulativeBonuses(targetRank)
	local bonuses = { XP = 0, Damage = 0, Speed = 0, Currency = 0, Health = 0 }
	local targetIndex = ProgressionConfig.RankIndex[targetRank]

	for i = 1, targetIndex - 1 do
		local rankAtStep = ProgressionConfig.RankOrder[i]
		local increment = ProgressionConfig.PromotionIncrements[rankAtStep]

		if increment ~= nil then
			bonuses.XP += increment.XP
			bonuses.Damage += increment.Damage
			bonuses.Speed += increment.Speed
			bonuses.Currency += increment.Currency
			bonuses.Health += increment.Health
		end
	end

	return bonuses
end

function AdminCommands.SetRank(admin, targetName, rankString)
	local target, profile, err = GetProfileOrWarn(admin, targetName)
	if err then
		return false, err
	end

	local rank = string.upper(rankString)
	if ProgressionConfig.RankIndex[rank] == nil then
		return false, "'" .. rankString .. "' is not a valid rank (F, E, D, C, B, A, S, SS, SSS)"
	end

	profile.Data.Rank = rank
	profile.Data.RankBonuses = ComputeCumulativeBonuses(rank)
	StatBonusService.Recompute(target, profile.Data)

	LeaderstatsService.UpdateRank(target, rank)

	return true, target.Name .. "'s rank set to " .. rank .. " with matching rank bonuses"
end

function AdminCommands.SetCurrency(admin, targetName, amountString)
	local target, profile, err = GetProfileOrWarn(admin, targetName)
	if err then
		return false, err
	end

	local amount = tonumber(amountString)
	if amount == nil or amount < 0 or amount ~= math.floor(amount) then
		return false, "Currency must be a non-negative whole number"
	end

	profile.Data.Currency = amount
	LeaderstatsService.UpdateSilver(target, amount)

	return true, target.Name .. "'s Silver set to " .. amount
end

function AdminCommands.AddXP(admin, targetName, amountString)
	local target, profile, err = GetProfileOrWarn(admin, targetName)
	if err then
		return false, err
	end

	local amount = tonumber(amountString)
	if amount == nil or amount <= 0 then
		return false, "XP amount must be a positive number"
	end

	ProgressionService.AwardXP(target, amount)

	return true, "Awarded " .. amount .. " XP to " .. target.Name
end

local function DeepCopyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = DeepCopyTable(value)
		else
			copy[key] = value
		end
	end
	return copy
end

function AdminCommands.ResetProgression(admin, targetName)
	local target, profile, err = GetProfileOrWarn(admin, targetName)
	if err then
		return false, err
	end

	local defaults = DeepCopyTable(ProgressionConfig.DefaultProgressionData)
	profile.Data.Rank = defaults.Rank
	profile.Data.Level = defaults.Level
	profile.Data.XP = defaults.XP
	profile.Data.Currency = defaults.Currency
	profile.Data.RankBonuses = defaults.RankBonuses
	StatBonusService.Recompute(target, profile.Data)

	LeaderstatsService.UpdateRank(target, profile.Data.Rank)
	LeaderstatsService.UpdateLevel(target, profile.Data.Level)
	LeaderstatsService.UpdateSilver(target, profile.Data.Currency)

	profile:Save()

	return true, target.Name .. "'s progression was reset to default and saved"
end

return AdminCommands