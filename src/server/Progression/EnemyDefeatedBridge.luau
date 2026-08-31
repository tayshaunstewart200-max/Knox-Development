local Players = game:GetService("Players")

local Signal = require(script.Parent.Signal)

local EnemyDefeatedBridge = {}

local CONTRIBUTION_THRESHOLD = 0.20
local CONTRIBUTION_PREFIX = "DmgContrib_"

EnemyDefeatedBridge.RewardEligible = Signal.New()

local function GetQualifyingUserIds(targetHumanoid)
	local maxHealth = targetHumanoid.MaxHealth
	local qualifying = {}

	local attributes = targetHumanoid:GetAttributes()
	for key, value in pairs(attributes) do
		if string.sub(key, 1, #CONTRIBUTION_PREFIX) == CONTRIBUTION_PREFIX then
			local userIdString = string.sub(key, #CONTRIBUTION_PREFIX + 1)
			local userId = tonumber(userIdString)
			if userId ~= nil and maxHealth > 0 and (value / maxHealth) >= CONTRIBUTION_THRESHOLD then
				table.insert(qualifying, userId)
			end
		end
	end

	return qualifying
end

function EnemyDefeatedBridge.ProcessDeath(enemyModel, xpReward, silverReward)
	local targetHumanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid then
		return
	end

	local qualifyingUserIds = GetQualifyingUserIds(targetHumanoid)

	for _, userId in ipairs(qualifyingUserIds) do
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			EnemyDefeatedBridge.RewardEligible:Fire(player, xpReward, silverReward)
		end
	end
end

return EnemyDefeatedBridge