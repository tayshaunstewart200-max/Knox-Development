local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local EliteMotionController = {}

local REPATH_THRESHOLD = 12
local WAYPOINT_REACHED_DISTANCE = 4

local activeMovements = {}
local lastDestination = {}
local steppingConnection = nil

local function getRoot(npc)
	return npc:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(npc)
	return npc:FindFirstChildOfClass("Humanoid")
end

local function stopMovement(npc)
	local existing = activeMovements[npc]
	if existing then
		existing.cancelled = true
		activeMovements[npc] = nil
	end
	lastDestination[npc] = nil
end

local function stepMovement(npc, movement)
	if movement.cancelled or not movement.waypoints then
		return
	end

	local root = getRoot(npc)
	local humanoid = getHumanoid(npc)
	if not root or not humanoid then
		activeMovements[npc] = nil
		return
	end

	local waypoint = movement.waypoints[movement.index]
	if (root.Position - waypoint.Position).Magnitude > WAYPOINT_REACHED_DISTANCE then
		return
	end

	movement.index += 1

	if movement.index > #movement.waypoints then
		activeMovements[npc] = nil
		if movement.onReached then
			movement.onReached()
		end
		return
	end

	humanoid:MoveTo(movement.waypoints[movement.index].Position)
end

local function startStepping()
	if steppingConnection then
		return
	end
	steppingConnection = RunService.Heartbeat:Connect(function()
		for npc, movement in pairs(activeMovements) do
			stepMovement(npc, movement)
		end
	end)
end

function EliteMotionController.Stop(npc)
	stopMovement(npc)
	local humanoid = getHumanoid(npc)
	if humanoid then
		humanoid:MoveTo(npc.HumanoidRootPart.Position)
	end
end

function EliteMotionController.FaceTarget(npc, target)
	local root = getRoot(npc)
	local character = target and target.Character
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not targetRoot then
		return
	end

	local lookAt = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
	root.CFrame = CFrame.lookAt(root.Position, lookAt)
end

function EliteMotionController.MoveTo(npc, destination, config, onReached)
	local lastPos = lastDestination[npc]
	if lastPos and activeMovements[npc] and (destination - lastPos).Magnitude < REPATH_THRESHOLD then
		return
	end

	stopMovement(npc)

	local humanoid = getHumanoid(npc)
	local root = getRoot(npc)
	if not humanoid or not root then
		return
	end

	lastDestination[npc] = destination

	local token = { cancelled = false }
	activeMovements[npc] = token

	local path = PathfindingService:CreatePath()
	local success = pcall(function()
		path:ComputeAsync(root.Position, destination)
	end)

	if token.cancelled then
		return
	end

	if not success or path.Status ~= Enum.PathStatus.Success then
		humanoid:MoveTo(destination)
		humanoid.MoveToFinished:Once(function(reached)
			if token.cancelled then
				return
			end
			activeMovements[npc] = nil
			if reached and onReached then
				onReached()
			end
		end)
		return
	end

	local waypoints = path:GetWaypoints()
	if #waypoints == 0 then
		activeMovements[npc] = nil
		return
	end

	token.waypoints = waypoints
	token.index = 1
	token.onReached = onReached

	humanoid:MoveTo(waypoints[1].Position)
	startStepping()
end

return EliteMotionController