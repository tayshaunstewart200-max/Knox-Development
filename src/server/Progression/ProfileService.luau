local Players = game:GetService("Players")
local ProfileStore = require(script.Parent.ProfileStore)
local ProgressionConfig = require(script.Parent.ProgressionConfig)
local LeaderstatsService = require(script.Parent.LeaderstatsService)
local StatBonusService = require(script.Parent.StatBonusService)

local ProfileService = {}
local Profiles = {}

local ProgressionStore = ProfileStore.New("PlayerProgression", ProgressionConfig.DefaultProgressionData)

function ProfileService.LoadProfile(player)
	local profile = ProgressionStore:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return Profiles[player] ~= nil or player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick("Profile failed to load. Please rejoin.")
		return nil
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		player:Kick("Profile session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end

	Profiles[player] = profile
	LeaderstatsService.Create(player, profile.Data)
	StatBonusService.Recompute(player, profile.Data)
	return profile
end

function ProfileService.GetProfile(player)
	return Profiles[player]
end

function ProfileService.ReleaseProfile(player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

Players.PlayerRemoving:Connect(function(player)
	ProfileService.ReleaseProfile(player)
end)

return ProfileService