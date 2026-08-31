local HitboxService = {}

local DEFAULT_CONFIG = {
	Player = { Size = Vector3.new(10, 5, 10), Offset = 4, ConeAngle = 0.3 },
	Enemy =  { Size = Vector3.new(8, 5, 8),  Offset = 3, ConeAngle = 0.2 },
}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function GetRoot(character)
	return character:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(character)
	return character:FindFirstChildOfClass("Humanoid")
end

local function ConeCheck(attackerRoot, targetRoot, coneAngle)
	local toTarget = (targetRoot.Position - attackerRoot.Position).Unit
	return attackerRoot.CFrame.LookVector:Dot(toTarget) >= coneAngle
end

local function LineOfSightCheck(attackerRoot, targetRoot)
	raycastParams.FilterDescendantsInstances = {attackerRoot.Parent, targetRoot.Parent}
	local result = workspace:Raycast(attackerRoot.Position, targetRoot.Position - attackerRoot.Position, raycastParams)
	return result == nil
end

local function ProcessHits(parts, attackerCharacter, config, lineOfSight)
	local hits = {}
	local seen = {}
	local attackerRoot = GetRoot(attackerCharacter)
	if not attackerRoot then return hits end

	for _, part in ipairs(parts) do
		local character = part.Parent
		if seen[character] or character == attackerCharacter then continue end

		local humanoid = GetHumanoid(character)
		if not humanoid or humanoid.Health <= 0 then continue end

		local targetRoot = GetRoot(character)
		if not targetRoot then continue end
		if not ConeCheck(attackerRoot, targetRoot, config.ConeAngle) then continue end
		if lineOfSight and not LineOfSightCheck(attackerRoot, targetRoot) then continue end

		seen[character] = true
		table.insert(hits, {
			character = character,
			humanoid = humanoid,
			root = targetRoot,
			distance = (attackerRoot.Position - targetRoot.Position).Magnitude,
		})
	end

	return hits
end

function HitboxService:GetHits(attackerCharacter, hitboxType, useLineOfSight)
	if not attackerCharacter then return {} end
	local config = DEFAULT_CONFIG[hitboxType] or DEFAULT_CONFIG.Player
	local root = GetRoot(attackerCharacter)
	if not root then return {} end

	overlapParams.FilterDescendantsInstances = {attackerCharacter}
	local parts = workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0, 0, -config.Offset), config.Size, overlapParams)
	return ProcessHits(parts, attackerCharacter, config, useLineOfSight or false)
end

function HitboxService:GetHitsWithConfig(attackerCharacter, config)
	if not attackerCharacter then return {} end
	local root = GetRoot(attackerCharacter)
	if not root then return {} end

	overlapParams.FilterDescendantsInstances = {attackerCharacter}
	local parts = workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0, 0, -config.Offset), config.Size, overlapParams)
	return ProcessHits(parts, attackerCharacter, config, false)
end

function HitboxService:GetHitsInRadius(origin, radius, exclude)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude or {}

	local size = Vector3.new(radius * 2, radius * 2, radius * 2)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(origin), size, params)

	local hits = {}
	local seen = {}

	for _, part in ipairs(parts) do
		local character = part.Parent
		if seen[character] then continue end
		local humanoid = GetHumanoid(character)
		if not humanoid or humanoid.Health <= 0 then continue end
		local root = GetRoot(character)
		if not root or (root.Position - origin).Magnitude > radius then continue end
		seen[character] = true
		table.insert(hits, {
			character = character,
			humanoid = humanoid,
			root = root,
			distance = (root.Position - origin).Magnitude,
		})
	end

	return hits
end

return HitboxService