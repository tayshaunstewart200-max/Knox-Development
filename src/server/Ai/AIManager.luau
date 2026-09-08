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
	LOSE_TARGET_BUFFER = 6,
}

local registry = {}
local registryByInstance = {}
local chasingSet = {}
local registryCount = 0
local detectionConnection = nil
local active = false
local detectionElapsed = 0
local chaseElapsed = 0
local cachedPlayerPositions = nil
local cachedPlayerCount = 0

local function refreshPlayerPositions()
	local positions = cachedPlayerPositions
	if positions then
		table.clear(positions)
	else
		positions = {}
		cachedPlayerPositions = positions
	end

	local count = 0
	local players = Players:GetPlayers()

	for i = 1, #players do
		local player = players[i]
		local character = player.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				positions[player] = root.Position
				count += 1
			end
		end
	end

	cachedPlayerCount = count
	return positions, count
end

local function computeTier(closestDist, detectionRange, isEngaged)
	if isEngaged or closestDist <= detectionRange * CONFIG.LOD_MID_MULTIPLIER then
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

local function runDetection(playerPositions, playerCount, dt)
	if playerCount == 0 then
		return
	end

	for npcId, entry in pairs(registry) do
		local root = entry.root

		if not root or not root.Parent then
			registryByInstance[entry.npc] = nil
			chasingSet[npcId] = nil
			registry[npcId] = nil
			registryCount -= 1
			continue
		end

		entry.detectionElapsed += dt
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
			local dx = npcPos.X - pos.X
			local dy = npcPos.Y - pos.Y
			local dz = npcPos.Z - pos.Z
			local distSq = dx * dx + dy * dy + dz * dz

			if distSq < closestDist then
				closestDist = distSq
				closestPlayer = player
			end
		end

		closestDist = math.sqrt(closestDist)

		local controller = entry.controller
		local isEngaged = controller:IsEngaged()
		local loseRange = detectionRange + CONFIG.LOSE_TARGET_BUFFER

		if closestPlayer and closestDist <= detectionRange then
			controller:OnPlayerDetected(closestPlayer, closestDist)
		elseif not (isEngaged and closestPlayer and closestDist <= loseRange) then
			controller:OnPlayerLost()
		end

		entry.lodTier = computeTier(closestDist, detectionRange, isEngaged)

		if controller:IsChasing() then
			chasingSet[npcId] = entry
		else
			chasingSet[npcId] = nil
		end
	end
end

local function runChaseRefresh(playerPositions, playerCount)
	if playerCount == 0 then
		return
	end

	for npcId, entry in pairs(chasingSet) do
		local controller = entry.controller
		if controller:IsChasing() then
			controller:RefreshChase(playerPositions)
		else
			chasingSet[npcId] = nil
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
		detectionElapsed = 0,
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
		chasingSet[npcId] = nil
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
		local playerCount = 0
		local gotPositions = false

		if detectionElapsed >= CONFIG.DETECTION_INTERVAL then
			local elapsedSinceLastDetection = detectionElapsed
			detectionElapsed = 0
			playerPositions, playerCount = refreshPlayerPositions()
			gotPositions = true
			runDetection(playerPositions, playerCount, elapsedSinceLastDetection)
		end

		if chaseElapsed >= CONFIG.CHASE_REFRESH_INTERVAL then
			chaseElapsed = 0
			if not gotPositions then
				playerPositions, playerCount = refreshPlayerPositions()
			end
			runChaseRefresh(playerPositions, playerCount)
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
	chasingSet = {}
	registryCount = 0
	cachedPlayerPositions = nil
	cachedPlayerCount = 0
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
