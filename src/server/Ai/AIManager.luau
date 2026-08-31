local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AIManager = {}

local CONFIG = {
	DETECTION_INTERVAL = 0.2,
	CHASE_REFRESH_INTERVAL = 0.5,
	MAX_NPCS = 200,
	LOD_MID_MULTIPLIER = 2,
	LOD_FAR_MULTIPLIER = 4,
	LOD_FAR_DETECTION_MULTIPLIER = 5,
}

local registry = {}
local registryByInstance = {}
local registryCount = 0
local detectionConnection = nil
local active = false
local detectionElapsed = 0
local chaseElapsed = 0

local function getPlayerPositions()
	local positions = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				positions[player] = root.Position
			end
		end
	end
	return positions
end

local function computeTier(closestDist, detectionRange, controller)
	if controller:IsEngaged() then
		return "Near"
	end
	if closestDist <= detectionRange * CONFIG.LOD_MID_MULTIPLIER then
		return "Near"
	elseif closestDist <= detectionRange * CONFIG.LOD_FAR_MULTIPLIER then
		return "Mid"
	else
		return "Far"
	end
end

local function getDetectionInterval(tier)
	if tier == "Far" then
		return CONFIG.DETECTION_INTERVAL * CONFIG.LOD_FAR_DETECTION_MULTIPLIER
	end
	return CONFIG.DETECTION_INTERVAL
end

local function runDetection(playerPositions, dt)
	if not next(playerPositions) then
		return
	end

	for npcId, entry in pairs(registry) do
		local root = entry.root

		if not root or not root.Parent then
			if entry.npc then
				registryByInstance[entry.npc] = nil
			end
			registry[npcId] = nil
			registryCount -= 1
			continue
		end

		entry.detectionElapsed = (entry.detectionElapsed or 0) + dt
		local requiredInterval = getDetectionInterval(entry.lodTier)

		if entry.detectionElapsed < requiredInterval then
			continue
		end
		entry.detectionElapsed = 0

		local npcPos = root.Position
		local detectionRange = entry.detectionRange
		local closestPlayer = nil
		local closestDist = math.huge

		for player, pos in pairs(playerPositions) do
			local dist = (npcPos - pos).Magnitude
			if dist < closestDist then
				closestDist = dist
				closestPlayer = player
			end
		end

		entry.lodTier = computeTier(closestDist, detectionRange, entry.controller)

		if closestPlayer and closestDist <= detectionRange then
			entry.controller:OnPlayerDetected(closestPlayer, closestDist)
		else
			entry.controller:OnPlayerLost()
		end
	end
end

local function runChaseRefresh(playerPositions)
	if not next(playerPositions) then
		return
	end

	for _, entry in pairs(registry) do
		local controller = entry.controller
		if controller:IsChasing() then
			controller:RefreshChase(playerPositions)
		end
	end
end

function AIManager.Register(npcId, controller, root, detectionRange)
	if registry[npcId] then
		return
	end
	if registryCount >= CONFIG.MAX_NPCS then
		warn("AIManager: MAX_NPCS limit reached")
		return
	end

	local npc = root.Parent

	local entry = {
		controller = controller,
		root = root,
		npc = npc,
		detectionRange = detectionRange,
		lodTier = "Near",
	}

	registry[npcId] = entry
	if npc then
		registryByInstance[npc] = entry
	end
	registryCount += 1
end

function AIManager.Unregister(npcId)
	local entry = registry[npcId]
	if entry then
		if entry.npc then
			registryByInstance[entry.npc] = nil
		end
		registry[npcId] = nil
		registryCount -= 1
	end
end

function AIManager.NotifyAttackEnd(npcId, targetAlive)
	local entry = registry[npcId]
	if entry then
		entry.controller:OnAttackEnd(targetAlive)
	end
end

function AIManager.NotifyDestinationReached(npcId)
	local entry = registry[npcId]
	if entry then
		entry.controller:OnDestinationReached()
	end
end

function AIManager.NotifyDeath(npcId)
	AIManager.Unregister(npcId)
end

function AIManager.Start()
	if active then
		return
	end
	active = true

	detectionConnection = RunService.Heartbeat:Connect(function(dt)
		detectionElapsed += dt
		chaseElapsed += dt

		local playerPositions = nil

		if detectionElapsed >= CONFIG.DETECTION_INTERVAL then
			local elapsedSinceLastDetection = detectionElapsed
			detectionElapsed = 0
			playerPositions = getPlayerPositions()
			runDetection(playerPositions, elapsedSinceLastDetection)
		end

		if chaseElapsed >= CONFIG.CHASE_REFRESH_INTERVAL then
			chaseElapsed = 0
			playerPositions = playerPositions or getPlayerPositions()
			runChaseRefresh(playerPositions)
		end
	end)
end

function AIManager.Stop()
	if detectionConnection then
		detectionConnection:Disconnect()
		detectionConnection = nil
	end
	active = false
	registry = {}
	registryByInstance = {}
	registryCount = 0
end

function AIManager.GetRegisteredCount()
	return registryCount
end

function AIManager.GetLODTier(npcId)
	local entry = registry[npcId]
	return entry and entry.lodTier or "Near"
end

function AIManager.GetLODTierByInstance(npc)
	local entry = registryByInstance[npc]
	return entry and entry.lodTier or "Near"
end

game:BindToClose(function()
	AIManager.Stop()
end)

return AIManager