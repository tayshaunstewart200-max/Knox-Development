local Players = game:GetService("Players")
local ProfileService = require(script.Parent.ProfileService)
local StatBonusService = require(script.Parent.StatBonusService)
local HealthService = require(script.Parent.HealthService)

local ProgressionInit = {}

local Started = false
local CharacterConnections = {}

local function OnCharacterAdded(player, character)
	local profile = ProfileService.GetProfile(player)
	if profile == nil then
		return
	end
	local multiplier = StatBonusService.GetHealthMultiplier(profile.Data)
	HealthService.ResetToFull(player, multiplier)
end

local function HookCharacter(player)
	if CharacterConnections[player] ~= nil then
		return
	end
	CharacterConnections[player] = player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character)
	end)
	if player.Character ~= nil then
		OnCharacterAdded(player, player.Character)
	end
end

local function UnhookCharacter(player)
	local connection = CharacterConnections[player]
	if connection ~= nil then
		connection:Disconnect()
		CharacterConnections[player] = nil
	end
end

local function OnPlayerAdded(player)
	HookCharacter(player)
	ProfileService.LoadProfile(player)
end

local function OnPlayerRemoving(player)
	UnhookCharacter(player)
end

function ProgressionInit.Start()
	if Started == true then
		return
	end
	Started = true

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(OnPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)
end

return ProgressionInit
