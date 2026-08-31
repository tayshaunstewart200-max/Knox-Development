local Players = game:GetService("Players")

local LeaderstatsService = {}

function LeaderstatsService.Create(player, progressionData)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Value = progressionData.Rank
	rank.Parent = leaderstats

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = progressionData.Level
	level.Parent = leaderstats

	local silver = Instance.new("IntValue")
	silver.Name = "Silver"
	silver.Value = progressionData.Currency or 0
	silver.Parent = leaderstats

	return leaderstats
end

function LeaderstatsService.UpdateRank(player, rank)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil then
		return
	end

	local rankValue = leaderstats:FindFirstChild("Rank")
	if rankValue ~= nil then
		rankValue.Value = rank
	end
end

function LeaderstatsService.UpdateLevel(player, level)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil then
		return
	end

	local levelValue = leaderstats:FindFirstChild("Level")
	if levelValue ~= nil then
		levelValue.Value = level
	end
end

function LeaderstatsService.UpdateSilver(player, silver)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats == nil then
		return
	end

	local silverValue = leaderstats:FindFirstChild("Silver")
	if silverValue ~= nil then
		silverValue.Value = silver
	end
end

Players.PlayerRemoving:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats ~= nil then
		leaderstats:Destroy()
	end
end)

return LeaderstatsService