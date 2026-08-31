local ZoneHandler = {}
local CONFIG = {
	DEFAULT_ZONE_RADIUS = 60,
	LEASH_RADIUS_MULTIPLIER = 1.5,
}
local zoneRegistry = {}
function ZoneHandler.Register(npc, home, radius)
	local id = npc
	zoneRegistry[id] = {
		home = home,
		radius = radius or CONFIG.DEFAULT_ZONE_RADIUS,
	}
end
function ZoneHandler.Unregister(npc)
	zoneRegistry[npc] = nil
end
function ZoneHandler.IsInZone(npc)
	local id = npc
	local entry = zoneRegistry[id]
	if not entry then return true end
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root then return true end
	return (root.Position - entry.home).Magnitude <= entry.radius
end
function ZoneHandler.IsOutsideLeash(npc)
	local id = npc
	local entry = zoneRegistry[id]
	if not entry then return false end
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local leashRadius = entry.radius * CONFIG.LEASH_RADIUS_MULTIPLIER
	return (root.Position - entry.home).Magnitude > leashRadius
end
function ZoneHandler.IsTargetInZone(npc, target)
	local id = npc
	local entry = zoneRegistry[id]
	if not entry then return true end
	local character = target.Character
	if not character then return false end
	local targetRoot = character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return false end
	return (targetRoot.Position - entry.home).Magnitude <= entry.radius
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