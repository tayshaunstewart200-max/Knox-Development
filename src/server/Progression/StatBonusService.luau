local HealthService = require(script.Parent.HealthService)

local StatBonusService = {}
local function ComputeMultiplier(bonusPercent)
	return 1 + (bonusPercent / 100)
end
function StatBonusService.Recompute(player, data)
	data.CachedXPMultiplier = ComputeMultiplier(data.RankBonuses.XP)
	data.CachedCurrencyMultiplier = ComputeMultiplier(data.RankBonuses.Currency)
	data.CachedDamageMultiplier = ComputeMultiplier(data.RankBonuses.Damage)
	data.CachedSpeedMultiplier = ComputeMultiplier(data.RankBonuses.Speed)
	data.CachedHealthMultiplier = ComputeMultiplier(data.RankBonuses.Health)
	player:SetAttribute("SpeedMultiplier", data.CachedSpeedMultiplier)
	HealthService.SetMaxHealthMultiplier(player, data.CachedHealthMultiplier)
end
function StatBonusService.GetXPMultiplier(data)
	return data.CachedXPMultiplier or 1
end
function StatBonusService.GetCurrencyMultiplier(data)
	return data.CachedCurrencyMultiplier or 1
end
function StatBonusService.GetDamageMultiplier(data)
	return data.CachedDamageMultiplier or 1
end
function StatBonusService.GetSpeedMultiplier(data)
	return data.CachedSpeedMultiplier or 1
end
function StatBonusService.GetHealthMultiplier(data)
	return data.CachedHealthMultiplier or 1
end
return StatBonusService