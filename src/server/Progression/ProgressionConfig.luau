local ProgressionConfig = {}
ProgressionConfig.PromotionThreshold = 100
ProgressionConfig.RankOrder = {
	"F", "E", "D", "C", "B", "A", "S", "SS", "SSS",
}
ProgressionConfig.RankIndex = {}
for index, rank in ipairs(ProgressionConfig.RankOrder) do
	ProgressionConfig.RankIndex[rank] = index
end
ProgressionConfig.RankMultiplier = {
	F = 1,
	E = 1.15,
	D = 1.3,
	C = 1.55,
	B = 1.85,
	A = 2.2,
	S = 2.8,
	SS = 3.6,
	SSS = 4.6,
}
ProgressionConfig.PromotionIncrements = {
	F = { XP = 0.5, Damage = 1.2, Speed = 0.5, Currency = 1.2, Health = 2 },
	E = { XP = 0.5, Damage = 1.2, Speed = 0.5, Currency = 1.2, Health = 2 },
	D = { XP = 0.5, Damage = 1.2, Speed = 0.5, Currency = 1.2, Health = 2 },
	C = { XP = 1.2, Damage = 1.2, Speed = 1.2, Currency = 1.2, Health = 2.5 },
	B = { XP = 1.2, Damage = 1.2, Speed = 1.2, Currency = 1.2, Health = 3 },
	A = { XP = 1.5, Damage = 1.5, Speed = 1.5, Currency = 1.5, Health = 5 },
	S = { XP = 1.5, Damage = 1.5, Speed = 1.5, Currency = 1.5, Health = 7.5 },
	SS = { XP = 1.5, Damage = 1.5, Speed = 1.5, Currency = 1.5, Health = 10 },
	SSS = { XP = 0, Damage = 0, Speed = 0, Currency = 0, Health = 25 },
}
ProgressionConfig.BaseCurve = {
	Base = 50,
	Exponent = 1.65,
}
ProgressionConfig.PromotionCurrencyReward = {
	F = 250,
	E = 400,
	D = 650,
	C = 1000,
	B = 1600,
	A = 2600,
	S = 4200,
	SS = 6800,
	SSS = 0,
}
ProgressionConfig.DefaultProgressionData = {
	Rank = "F",
	Level = 1,
	XP = 0,
	Currency = 0,
	RankBonuses = {
		XP = 0,
		Damage = 0,
		Speed = 0,
		Currency = 0,
		Health = 0,
	},
}
function ProgressionConfig.GetNextRank(currentRank)
	local index = ProgressionConfig.RankIndex[currentRank]
	if index == nil then
		return nil
	end
	return ProgressionConfig.RankOrder[index + 1]
end
function ProgressionConfig.XPRequiredForLevel(level, rank)
	local multiplier = ProgressionConfig.RankMultiplier[rank] or 1
	local base = ProgressionConfig.BaseCurve.Base
	local exponent = ProgressionConfig.BaseCurve.Exponent
	return math.floor(base * (level ^ exponent) * multiplier)
end
return ProgressionConfig