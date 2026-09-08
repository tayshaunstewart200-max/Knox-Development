local ZoneHandler = {}

local CONFIG = {
	DEFAULT_ZONE_RADIUS = 60,
	LEASH_RADIUS_MULTIPLIER = 1.5,
}

local zoneRegistry = {}

function ZoneHandler.Register(npc, home, radius)
	radius = radius or CONFIG.DEFAULT_ZONE_RADIUS
	zoneRegistry[npc] = {
		home = home,
		radius = radius,
		leashRadius = radius * CONFIG.LEASH_RADIUS_MULTIPLIER,
	}
end

function ZoneHandler.Unregister(npc)
	zoneRegistry[npc] = nil
end

function ZoneHandler.IsInZone(npc)
	local entry = zoneRegistry[npc]
	if not entry then
		return true
	end

	local root = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	if not root then
		return true
	end

	local dx = root.Position.X - entry.home.X
	local dz = root.Position.Z - entry.home.Z
	local dy = root.Position.Y - entry.home.Y

	return (dx * dx + dy * dy + dz * dz) <= (entry.radius * entry.radius)
end

function ZoneHandler.IsOutsideLeash(npc)
	local entry = zoneRegistry[npc]
	if not entry then
		return false
	end

	local root = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local dx = root.Position.X - entry.home.X
	local dy = root.Position.Y - entry.home.Y
	local dz = root.Position.Z - entry.home.Z

	return (dx * dx + dy * dy + dz * dz) > (entry.leashRadius * entry.leashRadius)
end

function ZoneHandler.IsTargetInZone(npc, target)
	local entry = zoneRegistry[npc]
	if not entry then
		return true
	end

	local character = target.Character
	if not character then
		return false
	end

	local targetRoot = character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		return false
	end

	local dx = targetRoot.Position.X - entry.home.X
	local dy = targetRoot.Position.Y - entry.home.Y
	local dz = targetRoot.Position.Z - entry.home.Z

	return (dx * dx + dy * dy + dz * dz) <= (entry.radius * entry.radius)
end

function ZoneHandler.GetHome(npc)
	local entry = zoneRegistry[npc]
	return entry and entry.home or nil
end

function ZoneHandler.GetZoneRadius(npc)
	local entry = zoneRegistry[npc]
	return entry and entry.radius or CONFIG.DEFAULT_ZONE_RADIUS
end

return ZoneHandler
