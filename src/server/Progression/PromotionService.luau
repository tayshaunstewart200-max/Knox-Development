local ProfileService = require(script.Parent.ProfileService)
local ProgressionConfig = require(script.Parent.ProgressionConfig)
local RewardService = require(script.Parent.RewardService)
local LeaderstatsService = require(script.Parent.LeaderstatsService)
local StatBonusService = require(script.Parent.StatBonusService)
local Signal = require(script.Parent.Signal)

local PromotionService = {}
PromotionService.Promoted = Signal.New()

function PromotionService.Promote(player)
	local profile = ProfileService.GetProfile(player)
	if profile == nil then
		return false
	end

	local data = profile.Data
	if data.Level < ProgressionConfig.PromotionThreshold then
		return false
	end

	local previousRank = data.Rank
	if ProgressionConfig.RankIndex[previousRank] == nil then
		return false
	end

	local nextRank = ProgressionConfig.GetNextRank(previousRank)
	if nextRank == nil then
		return false
	end

	if ProgressionConfig.RankMultiplier[nextRank] == nil then
		return false
	end

	if data.RankBonuses == nil then
		return false
	end

	local increment = ProgressionConfig.PromotionIncrements[previousRank]
	if increment ~= nil then
		data.RankBonuses.XP += increment.XP
		data.RankBonuses.Damage += increment.Damage
		data.RankBonuses.Speed += increment.Speed
		data.RankBonuses.Currency += increment.Currency
		data.RankBonuses.Health += increment.Health
	end

	data.Rank = nextRank
	data.Level -= ProgressionConfig.PromotionThreshold

	StatBonusService.Recompute(player, data)

	LeaderstatsService.UpdateRank(player, data.Rank)
	LeaderstatsService.UpdateLevel(player, data.Level)

	local currencyReward = ProgressionConfig.PromotionCurrencyReward[previousRank]
	if currencyReward ~= nil and currencyReward > 0 then
		RewardService.GrantCurrency(player, currencyReward)
	end

	PromotionService.Promoted:Fire(player, previousRank, nextRank, data.Level)
	return true
end

function PromotionService.CanPromote(player)
	local profile = ProfileService.GetProfile(player)
	if profile == nil then
		return false
	end
	local data = profile.Data
	return data.Level >= ProgressionConfig.PromotionThreshold
		and ProgressionConfig.GetNextRank(data.Rank) ~= nil
end

return PromotionService
