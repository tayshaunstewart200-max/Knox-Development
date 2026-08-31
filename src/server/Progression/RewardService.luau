local ProfileService = require(script.Parent.ProfileService)
local LeaderstatsService = require(script.Parent.LeaderstatsService)
local StatBonusService = require(script.Parent.StatBonusService)
local Signal = require(script.Parent.Signal)

local RewardService = {}
RewardService.CurrencyGranted = Signal.New()
RewardService.ItemGranted = Signal.New()

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

function RewardService.GrantRewardTable(player, rewardTable)
	if rewardTable.Currency ~= nil then
		RewardService.GrantCurrency(player, rewardTable.Currency)
	end
	if rewardTable.Items ~= nil then
		for _, item in ipairs(rewardTable.Items) do
			RewardService.GrantItem(player, item.Id, item.Quantity)
		end
	end
end

return RewardService