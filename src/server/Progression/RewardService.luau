local ProfileService = require(script.Parent.ProfileService)
local LeaderstatsService = require(script.Parent.LeaderstatsService)
local StatBonusService = require(script.Parent.StatBonusService)
local ProgressionService = require(script.Parent.ProgressionService)
local Signal = require(script.Parent.Signal)
local ContributionService = require(script.Parent.ContributionService)

local RewardService = {}
RewardService.CurrencyGranted = Signal.New()
RewardService.ItemGranted = Signal.New()
RewardService.RewardGranted = Signal.New()

local function IsFiniteNonNegative(n)
	return type(n) == "number" and n == n and n ~= math.huge and n >= 0
end

local function RollRange(range)
	if not range or not IsFiniteNonNegative(range.Min) or not IsFiniteNonNegative(range.Max) then
		return 0
	end
	if range.Max < range.Min then
		return math.floor(range.Min)
	end
	return math.random(math.floor(range.Min), math.floor(range.Max))
end

local function SplitWithRemainder(total, shares)
	local n = #shares
	local result = table.create(n, 0)
	if n == 0 or not IsFiniteNonNegative(total) or total <= 0 then
		return result
	end

	local floors = table.create(n)
	local remainders = table.create(n)
	local flooredSum = 0

	for i, share in ipairs(shares) do
		local raw = total * share
		local floor = math.floor(raw)
		floors[i] = floor
		remainders[i] = raw - floor
		flooredSum += floor
	end

	local leftover = math.floor(total) - flooredSum

	local order = {}
	for i = 1, n do
		order[i] = i
	end
	table.sort(order, function(a, b)
		return remainders[a] > remainders[b]
	end)

	for i = 1, n do
		result[i] = floors[i]
	end
	for i = 1, leftover do
		local idx = order[i]
		if not idx then
			break
		end
		result[idx] += 1
	end

	return result
end

function RewardService.GrantCurrency(player, amount)
	if amount == nil or amount <= 0 then
		return
	end

	local profile = ProfileService.GetProfile(player)
	if profile == nil then
		return
	end

	local data = profile.Data
	local multiplier = StatBonusService.GetCurrencyMultiplier(data)
	local grantedAmount = math.floor(amount * multiplier)

	data.Currency = (data.Currency or 0) + grantedAmount
	LeaderstatsService.UpdateSilver(player, data.Currency)
	RewardService.CurrencyGranted:Fire(player, grantedAmount)
end

function RewardService.GrantItem(player, itemId, quantity)
	quantity = quantity or 1
	local profile = ProfileService.GetProfile(player)
	if profile == nil then
		return
	end

	local data = profile.Data
	data.Inventory = data.Inventory or {}
	data.Inventory[itemId] = (data.Inventory[itemId] or 0) + quantity
	RewardService.ItemGranted:Fire(player, itemId, quantity)
end

function RewardService.GrantBundle(player, bundle)
	if not player or not bundle then
		return
	end

	if bundle.XP and bundle.XP > 0 then
		ProgressionService.AwardXP(player, bundle.XP)
	end

	if bundle.Currency then
		for _, amount in pairs(bundle.Currency) do
			RewardService.GrantCurrency(player, amount)
		end
	end

	if bundle.Items then
		for _, item in ipairs(bundle.Items) do
			RewardService.GrantItem(player, item.Id, item.Quantity)
		end
	end

	RewardService.RewardGranted:Fire(player, bundle)
end

-- policy.Type == "Participation": every player at/above policy.MinimumContributionPercent
-- gets the full reward. policy.Type == "Proportional": reward is split by contribution
-- share among players at/above policy.MinimumContributionPercent (0 by default).
local function ResolvePolicy(targetHumanoid, policy)
	if not policy or not targetHumanoid then
		return {}, {}
	end

	local minimumPercent = policy.MinimumContributionPercent or 0
	local qualifying, _, total = ContributionService:GetQualifyingPlayers(targetHumanoid, minimumPercent)

	if #qualifying == 0 then
		return {}, {}
	end

	if policy.Type == "Proportional" then
		if total <= 0 then
			return {}, {}
		end
		local shares = {}
		for i, entry in ipairs(qualifying) do
			shares[i] = entry.damage / total
		end
		return qualifying, shares
	end

	-- Participation (default): everyone qualifying gets share 1.0 independently.
	local shares = table.create(#qualifying, 1)
	return qualifying, shares
end

function RewardService.ProcessDeath(targetHumanoid, policy, rewardConfig)
	if not targetHumanoid or not policy or not rewardConfig then
		return
	end

	local qualifying, shares = ResolvePolicy(targetHumanoid, policy)
	if #qualifying == 0 then
		warn("[RewardService] no qualifying players for", targetHumanoid.Parent and targetHumanoid.Parent.Name or "unknown", "- reward not granted")
		return
	end

	local totalXP = RollRange(rewardConfig.XPReward)
	local totalSilver = RollRange(rewardConfig.SilverReward)

	if policy.Type == "Proportional" then
		local xpSplit = SplitWithRemainder(totalXP, shares)
		local silverSplit = SplitWithRemainder(totalSilver, shares)

		for i, entry in ipairs(qualifying) do
			RewardService.GrantBundle(entry.player, {
				XP = xpSplit[i],
				Currency = { Silver = silverSplit[i] },
			})
		end
	else
		for _, entry in ipairs(qualifying) do
			RewardService.GrantBundle(entry.player, {
				XP = totalXP,
				Currency = { Silver = totalSilver },
			})
		end
	end
end

return RewardService
