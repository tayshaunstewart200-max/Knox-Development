local RemoteGuard = {}

local Players = game:GetService("Players")

local MAX_REQUESTS_PER_SECOND = 10
local FLOOD_BAN_DURATION = 5

local requestCounts = {}
local bannedPlayers = {}

local function IsFlooding(player)
	local now = tick()
	if bannedPlayers[player] then
		if now < bannedPlayers[player] then return true end
		bannedPlayers[player] = nil
	end

	if not requestCounts[player] then
		requestCounts[player] = { count = 0, resetTime = now + 1 }
	end

	local data = requestCounts[player]
	if now > data.resetTime then
		data.count = 0
		data.resetTime = now + 1
	end

	data.count += 1

	if data.count > MAX_REQUESTS_PER_SECOND then
		bannedPlayers[player] = now + FLOOD_BAN_DURATION
		warn("[RemoteGuard] Flood detected from", player.Name)
		return true
	end

	return false
end

local function IsCharacterValid(player)
	local character = player.Character
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	if not character:FindFirstChild("HumanoidRootPart") then return false end
	return true
end

function RemoteGuard:Wrap(remote, callback)
	remote.OnServerEvent:Connect(function(player, ...)
		if IsFlooding(player) then return end
		if not IsCharacterValid(player) then return end
		callback(player, ...)
	end)
end

function RemoteGuard:Cleanup(player)
	requestCounts[player] = nil
	bannedPlayers[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	RemoteGuard:Cleanup(player)
end)

return RemoteGuard