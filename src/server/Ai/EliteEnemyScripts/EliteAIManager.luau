local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EliteAIManager = {}

local CONFIG = {
	DETECTION_INTERVAL = 0.3,
	THINK_INTERVAL = 0.15,
}

local registry = {}
local registryCount = 0
local heartbeatConnection = nil
local active = false
local detectionElapsed = 0
local thinkElapsed = 0

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

local function runDetection(playerPositions)
	for eliteId, entry in pairs(registry) do
		local root = entry.root
		if not root or not root.Parent then
			registry[eliteId] = nil
			registryCount -= 1
			continue
		end

		entry.nearestPlayer = nil

		if next(playerPositions) then
			local elitePos = root.Position
			local closestPlayer = nil
			local closestDist = math.huge

			for player, pos in pairs(playerPositions) do
				local dist = (elitePos - pos).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestPlayer = player
				end
			end

			if closestPlayer and closestDist <= entry.detectionRange then
				entry.nearestPlayer = closestPlayer
			end
		end
	end
end

local function runThink()
	for _, entry in pairs(registry) do
		entry.brain:Think(entry.nearestPlayer)
	end
end

function EliteAIManager.Register(eliteId, brain, root, detectionRange)
	if registry[eliteId] then
		return
	end
	registry[eliteId] = {
		brain = brain,
		root = root,
		detectionRange = detectionRange,
		nearestPlayer = nil,
	}
	registryCount += 1
end

function EliteAIManager.Unregister(eliteId)
	if registry[eliteId] then
		registry[eliteId] = nil
		registryCount -= 1
	end
end

function EliteAIManager.Start()
	if active then
		return
	end
	active = true
	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		detectionElapsed += dt
		thinkElapsed += dt

		if detectionElapsed >= CONFIG.DETECTION_INTERVAL then
			detectionElapsed = 0
			runDetection(getPlayerPositions())
		end

		if thinkElapsed >= CONFIG.THINK_INTERVAL then
			thinkElapsed = 0
			runThink()
		end
	end)
end

function EliteAIManager.Stop()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	active = false
	registry = {}
	registryCount = 0
end

function EliteAIManager.GetRegisteredCount()
	return registryCount
end

game:BindToClose(function()
	EliteAIManager.Stop()
end)

return EliteAIManager