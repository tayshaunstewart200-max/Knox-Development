local HealthService = {}

local BASE_MAX_HEALTH = 100

local function ApplyHealth(player, multiplier)
	print("[HealthService] SetMaxHealthMultiplier called for", player.Name, "multiplier:", multiplier)
	local character = player.Character
	if character == nil then
		print("[HealthService] ABORT - no character for", player.Name)
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		print("[HealthService] ABORT - no humanoid for", player.Name)
		return
	end
	local previousMax = humanoid.MaxHealth
	local newMax = BASE_MAX_HEALTH * multiplier
	local ratio = humanoid.Health / previousMax
	humanoid.MaxHealth = newMax
	humanoid.Health = newMax * ratio
	print("[HealthService]", player.Name, "MaxHealth", previousMax, "->", newMax, "Health set to", humanoid.Health)
end

function HealthService.SetMaxHealthMultiplier(player, multiplier)
	ApplyHealth(player, multiplier)
end

function HealthService.ResetToFull(player, multiplier)
	print("[HealthService] ResetToFull called for", player.Name, "multiplier:", multiplier)
	local character = player.Character
	if character == nil then
		print("[HealthService] ABORT - no character for", player.Name)
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		print("[HealthService] ABORT - no humanoid for", player.Name)
		return
	end
	local newMax = BASE_MAX_HEALTH * multiplier
	humanoid.MaxHealth = newMax
	humanoid.Health = newMax
	print("[HealthService]", player.Name, "reset to MaxHealth", newMax, "Health", humanoid.Health)
end

return HealthService