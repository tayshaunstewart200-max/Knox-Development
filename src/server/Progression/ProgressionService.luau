local ProfileService = require(script.Parent.ProfileService)
local ProgressionConfig = require(script.Parent.ProgressionConfig)
local LeaderstatsService = require(script.Parent.LeaderstatsService)
local StatBonusService = require(script.Parent.StatBonusService)
local Signal = require(script.Parent.Signal)

local ProgressionService = {}
ProgressionService.LevelUp = Signal.New()
ProgressionService.PromotionAvailable = Signal.New()

local function IsValidXPAmount(amount)
	return type(amount) == "number" and amount == amount and amount ~= math.huge and amount > 0
end

local function IsEligible(data)
	return data.Level >= ProgressionConfig.PromotionThreshold and ProgressionConfig.GetNextRank(data.Rank) ~= nil
end

local function ProcessLevelUps(player, data)
	local leveledUp = false
	while true do
		local required = ProgressionConfig.XPRequiredForLevel(data.Level, data.Rank)
		if data.XP < required then
			break
		end
		data.XP -= required
		data.Level += 1
		leveledUp = true
	end
	if leveledUp then
		LeaderstatsService.UpdateLevel(player, data.Level)
	end
	return leveledUp
end

function ProgressionService.AwardXP(player, amount)
	if not IsValidXPAmount(amount) then
		return
	end
	local profile = ProfileService.GetProfile(player)
	if profile == nil then
		return
	end
	local data = profile.Data
	local wasEligible = IsEligible(data)
	local multiplier = StatBonusService.GetXPMultiplier(data)
	data.XP += amount * multiplier
	local leveledUp = ProcessLevelUps(player, data)
	if leveledUp then
		ProgressionService.LevelUp:Fire(player, data.Level, data.Rank)
	end
	local nowEligible = IsEligible(data)
	if nowEligible and not wasEligible then
		ProgressionService.PromotionAvailable:Fire(player, data.Rank, data.Level)
	end
end

function ProgressionService.GetProgressionData(player)
	local profile = ProfileService.GetProfile(player)
	if profile == nil then
		return nil
	end
	return profile.Data
end

function ProgressionService.IsEligibleForPromotion(player)
	local data = ProgressionService.GetProgressionData(player)
	if data == nil then
		return false
	end
	return IsEligible(data)
end

return ProgressionService
