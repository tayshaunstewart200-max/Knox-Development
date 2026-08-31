local EliteStateManager = require(script.Parent.EliteStateManager)
local EliteMemory = require(script.Parent.EliteMemory)

local EliteBrain = {}
EliteBrain.__index = EliteBrain

local CONFIG = {
	HEAL_HEALTH_THRESHOLD = 0.2,
	COMBAT_WEIGHTS = {
		Combo = 70,
		Heavy = 25,
	},
	MIN_OBSERVE_TIME = 0.6,
	MIN_CHASE_TIME = 0.6,
	PATROL_RADIUS = 20,
	PATROL_WAIT_MIN = 3,
	PATROL_WAIT_MAX = 6,
}

function EliteBrain.new(npc, config, home)
	local self = setmetatable({}, EliteBrain)

	self.npc = npc
	self.config = config or CONFIG
	self.home = home
	self.stateManager = EliteStateManager.new(npc)
	self.memory = EliteMemory.new(self.config)

	self.target = nil
	self.lastTargetDistance = nil
	self.targetBackingAway = false
	self.targetDied = false
	self.targetDiedConnection = nil
	self.combatCooldowns = {}
	self.lowHealth = false
	self.stateEnteredAt = os.clock()
	self.patrolDestination = nil
	self.patrolWaitUntil = nil
	self.commandCallback = nil

	self.stateManager:OnTransition(function(n, from, to)
		self:_onStateChanged(from, to)
	end)

	return self
end

function EliteBrain:GetState()
	return self.stateManager:GetState()
end

function EliteBrain:GetCombatState()
	return self.stateManager:GetCombatState()
end

function EliteBrain:GetTarget()
	return self.target
end

function EliteBrain:Transition(state)
	return self.stateManager:Transition(state)
end

function EliteBrain:OnTransition(callback)
	self.stateManager:OnTransition(callback)
end

function EliteBrain:OnCombatTransition(callback)
	self.stateManager:OnCombatTransition(callback)
end

function EliteBrain:OnCommand(callback)
	self.commandCallback = callback
end

function EliteBrain:Kill()
	self.stateManager:Kill()
	self:Destroy()
end

function EliteBrain:RecordHit(player)
	if self.stateManager:GetState() == "Dead" then
		return
	end

	self.memory:RecordHostile(player.UserId)

	if self.target ~= player then
		self:SetTarget(player)
	end

	if self.stateManager:IsCombatLocked() then
		return
	end

	local state = self.stateManager:GetState()
	if state == "Idle" or state == "Patrol" then
		self.stateManager:Transition("Observe")
	end
end

function EliteBrain:SetTarget(target)
	self:_clearTargetTracking()

	self.target = target
	self.lastTargetDistance = nil
	self.targetBackingAway = false
	self.targetDied = false

	if target then
		local character = target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			self.targetDiedConnection = humanoid.Died:Once(function()
				self.targetDied = true
			end)
		end
	end
end

function EliteBrain:_clearTargetTracking()
	if self.targetDiedConnection then
		self.targetDiedConnection:Disconnect()
		self.targetDiedConnection = nil
	end
end

function EliteBrain:_onStateChanged(from, to)
	self.stateEnteredAt = os.clock()
	if to == "Patrol" then
		self.patrolDestination = nil
		self.patrolWaitUntil = nil
	end
end

function EliteBrain:_sendCommand(command)
	if self.commandCallback then
		self.commandCallback(command)
	end
end

function EliteBrain:_getTargetDistance()
	if not self.target then
		return nil
	end
	local character = self.target.Character
	if not character then
		return nil
	end
	local targetRoot = character:FindFirstChild("HumanoidRootPart")
	local npcRoot = self.npc:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not npcRoot then
		return nil
	end
	return (npcRoot.Position - targetRoot.Position).Magnitude
end

function EliteBrain:Think(nearestPlayer)
	if not self.stateManager:IsCombatLocked() then
		self:_perceive(nearestPlayer)
		self:_evaluate()
	end
	self:_sendStateCommand()
end

function EliteBrain:_perceive(nearestPlayer)
	if not nearestPlayer or self.target == nearestPlayer then
		return
	end

	local state = self.stateManager:GetState()
	if state == "Idle" or state == "Patrol" then
		self:SetTarget(nearestPlayer)
		self.stateManager:Transition("Observe")
	end
end

function EliteBrain:_evaluate()
	if not self:_validateTarget() then
		self:_evaluateDistanceAndChooseState()
		return
	end

	self:_evaluateHealth()
	self:_evaluateDistanceAndChooseState()
end

function EliteBrain:_validateTarget()
	if not self.target then
		return false
	end

	if self.targetDied then
		self:SetTarget(nil)
		return false
	end

	local character = self.target.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		self:SetTarget(nil)
		return false
	end

	return true
end

function EliteBrain:_evaluateHealth()
	local humanoid = self.npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		self.lowHealth = false
		return
	end
	self.lowHealth = (humanoid.Health / humanoid.MaxHealth) < self.config.HEAL_HEALTH_THRESHOLD
end

function EliteBrain:_tryTransition(fromState, toState)
	if fromState == "Observe" and (os.clock() - self.stateEnteredAt) < self.config.MIN_OBSERVE_TIME then
		return
	end
	if fromState == "Chase" and toState == "Patrol" and (os.clock() - self.stateEnteredAt) < self.config.MIN_CHASE_TIME then
		return
	end
	self.stateManager:Transition(toState)
end

function EliteBrain:_evaluateDistanceAndChooseState()
	local distance = self:_getTargetDistance()

	if distance and self.lastTargetDistance then
		self.targetBackingAway = distance > self.lastTargetDistance
	end
	self.lastTargetDistance = distance

	local currentState = self.stateManager:GetState()

	if not distance then
		self:_tryTransition(currentState, "Patrol")
		return
	end

	if not self.memory:IsHostile(self.target.UserId) then
		if distance > self.config.DisengageDistance then
			self:SetTarget(nil)
			self:_tryTransition(currentState, "Patrol")
			return
		end
		self:_tryTransition(currentState, "Observe")
		return
	end

	if distance <= self.config.AttackRange then
		self:_tryTransition(currentState, "Attack")
		if self.stateManager:GetState() == "Attack" and not self.stateManager:IsCombatLocked() then
			self:_chooseCombatAction()
		end
		return
	end

	self:_tryTransition(currentState, "Chase")
end

function EliteBrain:_chooseCombatAction()
	if self.lowHealth and self.targetBackingAway and self:_isCombatActionReady("Heal") then
		self:_enterCombatAction("Heal")
		return
	end
	self:_rollWeightedCombat()
end

function EliteBrain:_enterCombatAction(action)
	if not self.stateManager:EnterCombat(action) then
		return false
	end

	local cooldowns = self.config.COMBAT_COOLDOWNS or {}
	local cooldownDuration = cooldowns[action]
	if cooldownDuration and cooldownDuration > 0 then
		self.combatCooldowns[action] = os.clock() + cooldownDuration
	end

	return true
end

function EliteBrain:_isCombatActionReady(action)
	local readyAt = self.combatCooldowns[action]
	return not readyAt or os.clock() >= readyAt
end

function EliteBrain:_rollWeightedCombat()
	local weights = self.config.COMBAT_WEIGHTS

	local availableWeights = {}
	local total = 0

	for action, weight in pairs(weights) do
		if self:_isCombatActionReady(action) then
			availableWeights[action] = weight
			total += weight
		end
	end

	if total <= 0 then
		return
	end

	local roll = math.random() * total
	local cumulative = 0

	for action, weight in pairs(availableWeights) do
		cumulative += weight
		if roll <= cumulative then
			self:_enterCombatAction(action)
			return
		end
	end
end

function EliteBrain:_sendStateCommand()
	local state = self.stateManager:GetState()

	if state == "Patrol" then
		self:_drivePatrol()
	elseif state == "Observe" or state == "Attack" then
		self:_sendCommand({ Type = "StopAndFace", Target = self.target })
	elseif state == "Chase" then
		self:_driveChase()
	end
end

function EliteBrain:_driveChase()
	if not self.target then
		return
	end
	local character = self.target.Character
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		return
	end
	self:_sendCommand({ Type = "MoveTo", Destination = targetRoot.Position })
end

function EliteBrain:_drivePatrol()
	if self.patrolWaitUntil and os.clock() < self.patrolWaitUntil then
		return
	end

	if not self.patrolDestination then
		local angle = math.random() * math.pi * 2
		local radius = math.random() * self.config.PATROL_RADIUS
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		self.patrolDestination = self.home + offset
	end

	self:_sendCommand({
		Type = "MoveTo",
		Destination = self.patrolDestination,
		OnReached = function()
			self:_onPatrolWaypointReached()
		end,
	})
end

function EliteBrain:_onPatrolWaypointReached()
	self.patrolDestination = nil
	local config = self.config
	self.patrolWaitUntil = os.clock()
		+ config.PATROL_WAIT_MIN
		+ math.random() * (config.PATROL_WAIT_MAX - config.PATROL_WAIT_MIN)
end

function EliteBrain:FinishCombat()
	self.stateManager:FinishCombat()
end

function EliteBrain:Destroy()
	self:_clearTargetTracking()
end

return EliteBrain