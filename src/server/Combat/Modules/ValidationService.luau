local ValidationService = {}

local Players = game:GetService("Players")
local CombatStateManager = require(game:GetService("ReplicatedStorage").SharedModules.CombatStateManager)

local CONFIG = {
	MaxRequestsPerSecond = 8,
	FloodBanDuration = 10,
	MaxAttackDistance = 20,
	MaxDodgeDirectionMagnitude = 1.1,
	MinRequestInterval = 0.1,
}

local playerData = {}

local function GetData(player)
	if not playerData[player] then
		playerData[player] = {
			requestCount = 0,
			windowStart = tick(),
			lastRequestTime = 0,
			violations = 0,
			banned = false,
			banExpiry = 0,
		}
	end
	return playerData[player]
end

local function LogViolation(player, reason, data)
	local pData = GetData(player)
	pData.violations += 1
	warn(string.format("[ValidationService] VIOLATION | Player: %s | Reason: %s | Data: %s | Total: %d",
		player.Name, tostring(reason), tostring(data), pData.violations))
	if pData.violations >= 10 then
		warn(string.format("[ValidationService] Player %s flagged for review (%d violations)", player.Name, pData.violations))
	end
end

local function IsCharacterValid(player)
	local character = player.Character
	if not character then return false, "no character" end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false, "dead" end
	if not character:FindFirstChild("HumanoidRootPart") then return false, "no root" end
	return true, character
end

local function CheckFlood(player)
	local data = GetData(player)
	local now = tick()

	if data.banned then
		if now < data.banExpiry then return false, "banned" end
		data.banned = false
		data.violations = 0
	end

	if (now - data.lastRequestTime) < CONFIG.MinRequestInterval then
		LogViolation(player, "firing too fast", now - data.lastRequestTime)
		return false, "request too fast"
	end

	if (now - data.windowStart) >= 1 then
		data.requestCount = 0
		data.windowStart = now
	end

	data.requestCount += 1
	data.lastRequestTime = now

	if data.requestCount > CONFIG.MaxRequestsPerSecond then
		data.banned = true
		data.banExpiry = now + CONFIG.FloodBanDuration
		LogViolation(player, "flood detected", data.requestCount)
		return false, "flood detected"
	end

	return true
end

local function CheckState(character, action)
	if not CombatStateManager:CanAct(character, action) then
		return false, "invalid state for " .. action
	end
	return true
end

local function ValidateDirection(direction)
	if typeof(direction) ~= "Vector3" then return false end
	if direction ~= direction then return false end
	if direction.Magnitude > CONFIG.MaxDodgeDirectionMagnitude then return false end
	return true
end

function ValidationService:ValidateM1(player)
	local floodOk, floodReason = CheckFlood(player)
	if not floodOk then return false, floodReason end
	local charOk, character = IsCharacterValid(player)
	if not charOk then return false, character end
	local stateOk, stateReason = CheckState(character, "M1")
	if not stateOk then return false, stateReason end
	return true, character
end

function ValidationService:ValidateParry(player)
	local floodOk, floodReason = CheckFlood(player)
	if not floodOk then return false, floodReason end
	local charOk, character = IsCharacterValid(player)
	if not charOk then return false, character end
	local stateOk, stateReason = CheckState(character, "Parry")
	if not stateOk then return false, stateReason end
	return true, character
end

function ValidationService:ValidateDodge(player, direction)
	local floodOk, floodReason = CheckFlood(player)
	if not floodOk then return false, floodReason end
	local charOk, character = IsCharacterValid(player)
	if not charOk then return false, character end
	local stateOk, stateReason = CheckState(character, "Dodge")
	if not stateOk then return false, stateReason end
	if not ValidateDirection(direction) then
		LogViolation(player, "invalid dodge direction", tostring(direction))
		return false, "invalid direction"
	end
	return true, character
end

function ValidationService:ValidateHit(attackerHRP, targetCharacter, maxDistance)
	if not attackerHRP or not targetCharacter then return false end
	local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return false end
	return (attackerHRP.Position - targetHRP.Position).Magnitude <= (maxDistance or CONFIG.MaxAttackDistance)
end

function ValidationService:Cleanup(player)
	playerData[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	ValidationService:Cleanup(player)
end)

return ValidationService