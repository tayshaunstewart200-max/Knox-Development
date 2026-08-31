local ProgressionService = require(script.Parent.ProgressionService)
local RewardService = require(script.Parent.RewardService)
local EnemyDefeatedBridge = require(script.Parent.EnemyDefeatedBridge)

EnemyDefeatedBridge.RewardEligible:Connect(function(player, xpReward, silverReward)
	ProgressionService.AwardXP(player, xpReward)
	RewardService.GrantCurrency(player, silverReward)
end)

return true