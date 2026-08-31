local Players = game:GetService("Players")
local ProfileService = require(script.Parent.ProfileService)
local StatBonusService = require(script.Parent.StatBonusService)
local HealthService = require(script.Parent.HealthService)

local function OnCharacterAdded(player)
	local profile = ProfileService.GetProfile(player)
	if profile == nil then
		return
	end
	local multiplier = StatBonusService.GetHealthMultiplier(profile.Data)
	HealthService.ResetToFull(player, multiplier)
end

local function OnPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		OnCharacterAdded(player)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	OnPlayerAdded(player)
end
Players.PlayerAdded:Connect(OnPlayerAdded)