local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local AIManager = require(script.Parent.Parent.AIManager)

local MotionController = {}

local CONFIG = {
	ROAM_RADIUS = 20,
	ROAM_WAIT_MIN = 2,
	ROAM_WAIT_MAX = 5,
	ROAM_WAIT_MID_MULTIPLIER = 2,
	ROAM_WAIT_FAR_MULTIPLIER = 4,
	ROAM_FAIL_BACKOFF = 1.5,

	AGENT_RADIUS = 2,
	AGENT_HEIGHT = 5,
	AGENT_CAN_JUMP = true,
	MAX_JUMP_HEIGHT = 7,

	WAYPOINT_REACHED_RADIUS = 3,
	RETARGET_DISTANCE = 15,
	REPATH_INTERVAL = 0.5,
	STUCK_TIMEOUT = 2,
	STUCK_MIN_PROGRESS = 1,
}

local WAYPOINT_REACHED_RADIUS_SQ = CONFIG.WAYPOINT_REACHED_RADIUS * CONFIG.WAYPOINT_REACHED_RADIUS
local RETARGET_DISTANCE_SQ = CONFIG.RETARGET_DISTANCE * CONFIG.RETARGET_DISTANCE
local STUCK_MIN_PROGRESS_SQ = CONFIG.STUCK_MIN_PROGRESS * CONFIG.STUCK_MIN_PROGRESS

local active = {}
local roamThreads = {}

local function flatDistSq(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return dx * dx + dz * dz
end

local function distSq(a, b)
	local dx = a.X - b.X
	local dy = a.Y - b.Y
	local dz = a.Z - b.Z
	return dx * dx + dy * dy + dz * dz
end

local function cancelRoam(npc)
	local thread = roamThreads[npc]

	if not thread then
		return
	end

	if thread == coroutine.running() then
		return
	end

	pcall(task.cancel, thread)

	if roamThreads[npc] == thread then
		roamThreads[npc] = nil
	end
end

local function teardown(npc, keepChaseTarget)
	local entry = active[npc]

	if not entry then
		return
	end

	if entry.heartbeatConn then
		entry.heartbeatConn:Disconnect()
		entry.heartbeatConn = nil
	end

	if entry.thread then
		pcall(task.cancel, entry.thread)
		entry.thread = nil
	end

	if keepChaseTarget and entry.chaseTarget then
		active[npc] = {
			chaseTarget = entry.chaseTarget,
			chaseTargetRoot = entry.chaseTargetRoot,
		}
	else
		active[npc] = nil
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid:Move(Vector3.zero)
	end
end

local function setSpeed(npc, speed)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function computePath(startPos, endPos)
	local path = PathfindingService:CreatePath({
		AgentRadius = CONFIG.AGENT_RADIUS,
		AgentHeight = CONFIG.AGENT_HEIGHT,
		AgentCanJump = CONFIG.AGENT_CAN_JUMP,
		AgentJumpHeight = CONFIG.MAX_JUMP_HEIGHT,
	})

	local ok = pcall(function()
		path:ComputeAsync(startPos, endPos)
	end)

	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end

	return path
end

local function getRandomRoamPosition(home, radius)
	local angle = math.random() * math.pi * 2
	local dist = math.random() * radius

	return Vector3.new(
		home.X + math.cos(angle) * dist,
		home.Y,
		home.Z + math.sin(angle) * dist
	)
end

local function getRoamWaitMultiplier(npc)
	local tier = AIManager.GetLODTierByInstance(npc)

	if tier == "Far" then
		return CONFIG.ROAM_WAIT_FAR_MULTIPLIER
	elseif tier == "Mid" then
		return CONFIG.ROAM_WAIT_MID_MULTIPLIER
	end

	return 1
end

local function startSteering(
	npc,
	destination,
	onReached,
	onFailed,
	getDestination,
	stopDistance,
	chaseTarget,
	chaseTargetRoot
)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		if onFailed then
			onFailed()
		end

		return
	end

	teardown(npc, false)

	local stopDistanceSq = stopDistance and (stopDistance * stopDistance) or nil

	local entry = {
		waypoints = nil,
		waypointIndex = 1,
		lastPathTarget = nil,
		lastRepathClock = 0,
		lastProgressPos = root.Position,
		lastProgressClock = os.clock(),
		lastDirection = nil,
		chaseTarget = chaseTarget,
		chaseTargetRoot = chaseTargetRoot,
	}

	active[npc] = entry

	local function repath(targetPos)
		local currentRoot = npc:FindFirstChild("HumanoidRootPart")

		if not currentRoot then
			return false
		end

		local path = computePath(
			currentRoot.Position,
			targetPos
		)

		if not path then
			return false
		end

		local waypoints = path:GetWaypoints()

		if #waypoints == 0 then
			return false
		end

		entry.waypoints = waypoints
		entry.waypointIndex = math.min(2, #waypoints)
		entry.lastPathTarget = targetPos
		entry.lastRepathClock = os.clock()
		entry.lastProgressPos = currentRoot.Position
		entry.lastProgressClock = os.clock()

		return true
	end

	if not repath(destination) then
		local keptChaseTarget = chaseTarget

		if active[npc] == entry then
			active[npc] = nil
		end

		if keptChaseTarget then
			active[npc] = {
				chaseTarget = keptChaseTarget,
				chaseTargetRoot = chaseTargetRoot,
			}
		end

		if onFailed then
			onFailed()
		end

		return
	end

	entry.heartbeatConn = RunService.Heartbeat:Connect(function()
		if active[npc] ~= entry then
			return
		end

		local currentHumanoid = npc:FindFirstChildOfClass("Humanoid")
		local currentRoot = npc:FindFirstChild("HumanoidRootPart")

		if
			not currentHumanoid
			or not currentRoot
			or currentHumanoid.Health <= 0
		then
			teardown(npc, false)
			return
		end

		local currentDestination

		if getDestination then
			currentDestination = getDestination(entry)
		else
			currentDestination = destination
		end

		if not currentDestination then
			teardown(npc, false)

			if onFailed then
				onFailed()
			end

			return
		end

		if stopDistanceSq then
			local liveDistSq = distSq(currentRoot.Position, currentDestination)

			if liveDistSq <= stopDistanceSq then
				teardown(npc, true)

				if onReached then
					onReached()
				end

				return
			end
		end

		if
			entry.lastPathTarget
			and distSq(currentDestination, entry.lastPathTarget) >= RETARGET_DISTANCE_SQ
			and (os.clock() - entry.lastRepathClock) >= CONFIG.REPATH_INTERVAL
		then
			if not repath(currentDestination) then
				teardown(npc, false)

				if onFailed then
					onFailed()
				end

				return
			end
		end

		local waypoints = entry.waypoints
		local waypoint = waypoints[entry.waypointIndex]

		if not waypoint then
			teardown(npc, false)

			if onReached then
				onReached()
			end

			return
		end

		local waypointPos = waypoint.Position
		local rootPos = currentRoot.Position
		local flatDSq = flatDistSq(waypointPos, rootPos)

		if flatDSq <= WAYPOINT_REACHED_RADIUS_SQ then
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				currentHumanoid.Jump = true
			end

			entry.waypointIndex += 1

			if entry.waypointIndex > #waypoints then
				teardown(npc, false)

				if onReached then
					onReached()
				end

				return
			end

			waypoint = waypoints[entry.waypointIndex]
			waypointPos = waypoint.Position
		end

		local direction = Vector3.new(
			waypointPos.X - rootPos.X,
			0,
			waypointPos.Z - rootPos.Z
		)

		if direction.Magnitude > 0.5 then
			local normalized = direction.Unit

			if
				entry.lastDirection
				and entry.lastDirection:Dot(normalized) < -0.3
			then
				normalized = entry.lastDirection
			end

			currentHumanoid:Move(normalized)

			entry.lastDirection = normalized
		elseif entry.lastDirection then
			currentHumanoid:Move(entry.lastDirection)
		end

		local progressDSq = distSq(rootPos, entry.lastProgressPos)

		if progressDSq >= STUCK_MIN_PROGRESS_SQ then
			entry.lastProgressPos = rootPos
			entry.lastProgressClock = os.clock()
		elseif os.clock() - entry.lastProgressClock >= CONFIG.STUCK_TIMEOUT then
			if not repath(currentDestination) then
				teardown(npc, false)

				if onFailed then
					onFailed()
				end
			end
		end
	end)
end

function MotionController.Roam(npc, home, config)
	cancelRoam(npc)
	teardown(npc, false)

	setSpeed(npc, config.Speed * 0.5)

	local thread

	thread = task.spawn(function()
		while true do
			local humanoid = npc:FindFirstChildOfClass("Humanoid")

			if not humanoid or humanoid.Health <= 0 then
				if roamThreads[npc] == thread then
					roamThreads[npc] = nil
				end

				return
			end

			local target = getRandomRoamPosition(
				home,
				CONFIG.ROAM_RADIUS
			)

			local reached = false
			local failed = false

			startSteering(
				npc,
				target,

				function()
					reached = true
				end,

				function()
					failed = true
				end
			)

			if failed then
				task.wait(CONFIG.ROAM_FAIL_BACKOFF)
			else
				local elapsed = 0

				while
					not reached
					and not failed
					and elapsed < 10
				do
					task.wait(0.2)
					elapsed += 0.2

					if roamThreads[npc] ~= thread then
						return
					end
				end
			end

			if roamThreads[npc] ~= thread then
				return
			end

			if not failed then
				local waitMultiplier =
					getRoamWaitMultiplier(npc)

				task.wait(
					math.random(
						CONFIG.ROAM_WAIT_MIN,
						CONFIG.ROAM_WAIT_MAX
					) * waitMultiplier
				)
			end

			if roamThreads[npc] ~= thread then
				return
			end
		end
	end)

	roamThreads[npc] = thread
end

local function chaseGetDestination(entry)
	local target = entry.chaseTarget
	if not target then
		return nil
	end

	local targetRoot = entry.chaseTargetRoot

	if not targetRoot or not targetRoot.Parent then
		local character = target.Character

		if not character then
			entry.chaseTargetRoot = nil
			return nil
		end

		targetRoot = character:FindFirstChild("HumanoidRootPart")

		if not targetRoot then
			entry.chaseTargetRoot = nil
			return nil
		end

		entry.chaseTargetRoot = targetRoot
	end

	return targetRoot.Position
end

function MotionController.Chase(npc, target, config, onReached)
	cancelRoam(npc)

	setSpeed(npc, config.Speed)

	local existing = active[npc]

	if
		existing
		and existing.chaseTarget == target
		and existing.heartbeatConn
	then
		return
	end

	local character = target.Character

	if not character then
		if onReached then
			onReached()
		end

		return
	end

	local targetRoot = character:FindFirstChild("HumanoidRootPart")

	if not targetRoot then
		if onReached then
			onReached()
		end

		return
	end

	startSteering(
		npc,
		targetRoot.Position,
		onReached,

		function()
			if onReached then
				onReached()
			end
		end,

		chaseGetDestination,
		config.AttackRange,
		target,
		targetRoot
	)
end

function MotionController.MoveTo(npc, position, config, onReached)
	cancelRoam(npc)

	setSpeed(npc, config.Speed * 0.6)

	startSteering(
		npc,
		position,
		onReached,
		onReached
	)
end

function MotionController.Stop(npc)
	cancelRoam(npc)

	local entry = active[npc]

	local keepChaseTarget =
		entry ~= nil
		and entry.chaseTarget ~= nil

	teardown(npc, keepChaseTarget)
end

return MotionController
