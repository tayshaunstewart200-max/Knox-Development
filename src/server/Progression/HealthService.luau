local HealthService = {}
local BASE_MAX_HEALTH = 100

local function IsValidMultiplier(multiplier)
	return type(multiplier) == "number" and multiplier == multiplier and multiplier ~= math.huge and multiplier > 0
end

local function GetHumanoid(player)
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function HealthService.SetMaxHealthMultiplier(player, multiplier)
	if not IsValidMultiplier(multiplier) then
		return
	end
	local humanoid = GetHumanoid(player)
	if humanoid == nil then
		return
	end
	local previousMax = humanoid.MaxHealth
	if previousMax <= 0 then
		return
	end
	local newMax = BASE_MAX_HEALTH * multiplier
	local ratio = humanoid.Health / previousMax
	humanoid.MaxHealth = newMax
	humanoid.Health = newMax * ratio
end

function HealthService.ResetToFull(player, multiplier)
	if not IsValidMultiplier(multiplier) then
		return
	end
	local humanoid = GetHumanoid(player)
	if humanoid == nil then
		return
	end
	local newMax = BASE_MAX_HEALTH * multiplier
	humanoid.MaxHealth = newMax
	humanoid.Health = newMax
end

return HealthService
