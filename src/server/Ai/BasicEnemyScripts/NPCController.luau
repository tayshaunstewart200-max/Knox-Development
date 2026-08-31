local AIManager = require(script.Parent.Parent.AIManager)
local EnemyStateManager = require(script.Parent.Parent.EnemyStateManager)
local MotionController = require(script.Parent.Parent.Modules.MotionController)
local CombatModule = require(script.Parent.Parent.Modules.CombatModule)
local ZoneHandler = require(script.Parent.Parent.Modules.ZoneHandler)
local CleanupService = require(script.Parent.Parent.Modules.CleanupService)
local EnemyDefeatedBridge = require(script.Parent.Parent.Parent.Progression.EnemyDefeatedBridge)

local NPCController = {}
NPCController.__index = NPCController

function NPCController.new(npc, config)
	local self = setmetatable({}, NPCController)

	self.npc = npc
	self.config = config
	self.id = npc.Name .. "_" .. tostring(npc:GetAttribute("NpcId") or math.random(1, 999999))
	self.target = nil
	self.home = npc.HumanoidRootPart.Position
	self.alive = true

	self.stateManager = EnemyStateManager.new(npc)
	self.stateManager:OnTransition(function(n, from, to)
		self:_onStateChanged(from, to)
	end)

	npc.Humanoid.Died:Once(function()
		self:OnDeath()
	end)

	AIManager.Register(self.id, self, npc.HumanoidRootPart, config.DetectionRange)
	ZoneHandler.Register(npc, self.home, config.ZoneRadius)

	self:_enterRoam()

	return self
end

function NPCController:_onStateChanged(from, to)
	if to == "Roam" then
		self:_enterRoam()
	elseif to == "Chase" then
		self:_enterChase()
	elseif to == "Attack" then
		self:_enterAttack()
	elseif to == "Return" then
		self:_enterReturn()
	elseif to == "Dead" then
		self:_enterDead()
	end
end

function NPCController:_enterRoam()
	self.target = nil
	MotionController.Roam(self.npc, self.home, self.config)
end

function NPCController:_enterChase()
	if not self.target then
		self.stateManager:Transition("Roam")
		return
	end

	if ZoneHandler.IsOutsideLeash(self.npc) then
		self.stateManager:Transition("Return")
		return
	end

	MotionController.Chase(self.npc, self.target, self.config, function()
		AIManager.NotifyDestinationReached(self.id)
	end)
end

function NPCController:_enterAttack()
	if not self.target then
		self.stateManager:Transition("Roam")
		return
	end
	MotionController.Stop(self.npc)
	CombatModule.Attack(self.npc, self.target, self.config, function(targetAlive)
		AIManager.NotifyAttackEnd(self.id, targetAlive)
	end)
end

function NPCController:_enterReturn()
	self.target = nil
	MotionController.MoveTo(self.npc, self.home, self.config, function()
		AIManager.NotifyDestinationReached(self.id)
	end)
end

function NPCController:_enterDead()
	self.alive = false
	self.target = nil
	MotionController.Stop(self.npc)
end

function NPCController:IsChasing()
	return self.alive and self.stateManager:GetState() == "Chase"
end

function NPCController:IsEngaged()
	if not self.alive then
		return false
	end
	local state = self.stateManager:GetState()
	return state == "Chase" or state == "Attack"
end

function NPCController:RefreshChase(playerPositions)
	if not self.alive or not self.target then
		return
	end

	local targetPos = playerPositions[self.target]
	if not targetPos then
		return
	end

	local npcRoot = self.npc:FindFirstChild("HumanoidRootPart")
	if not npcRoot then
		return
	end

	local dist = (npcRoot.Position - targetPos).Magnitude

	if dist <= self.config.AttackRange then
		self.stateManager:Transition("Attack")
		return
	end

	if ZoneHandler.IsOutsideLeash(self.npc) then
		self.stateManager:Transition("Return")
		return
	end

	MotionController.Chase(self.npc, self.target, self.config, function()
		AIManager.NotifyDestinationReached(self.id)
	end)
end

function NPCController:OnPlayerDetected(player, distance)
	if not self.alive then
		return
	end

	if not ZoneHandler.IsTargetInZone(self.npc, player) then
		return
	end

	self.target = player

	local state = self.stateManager:GetState()

	if state == "Roam" or state == "Return" then
		self.stateManager:Transition("Chase")
	elseif state == "Chase" then
		if distance <= self.config.AttackRange then
			self.stateManager:Transition("Attack")
		end
	elseif state == "Attack" then
		if distance > self.config.AttackRange then
			self.stateManager:Transition("Chase")
		end
	end
end

function NPCController:OnPlayerLost()
	if not self.alive then
		return
	end

	local state = self.stateManager:GetState()

	if state == "Chase" or state == "Attack" then
		self.target = nil
		self.stateManager:Transition("Return")
	end
end

function NPCController:OnAttackEnd(targetAlive)
	if not self.alive then
		return
	end

	if not self.target then
		self.stateManager:Transition("Return")
		return
	end

	if targetAlive == false then
		self.target = nil
		self.stateManager:Transition("Return")
		return
	end

	local targetChar = self.target.Character
	if not targetChar then
		self.target = nil
		self.stateManager:Transition("Return")
		return
	end

	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetRoot then
		self.target = nil
		self.stateManager:Transition("Return")
		return
	end

	local root = self.npc.HumanoidRootPart
	local dist = (root.Position - targetRoot.Position).Magnitude

	if dist <= self.config.AttackRange then
		self:_enterAttack()
	else
		self.stateManager:Transition("Chase")
	end
end

function NPCController:OnDestinationReached()
	if not self.alive then
		return
	end

	local state = self.stateManager:GetState()

	if state == "Return" then
		self.stateManager:Transition("Roam")
	elseif state == "Chase" then
		if self.target then
			self.stateManager:Transition("Attack")
		else
			self.stateManager:Transition("Return")
		end
	end
end

function NPCController:OnDeath()
	if not self.alive then
		return
	end
	self.alive = false
	self.target = nil
	AIManager.Unregister(self.id)
	ZoneHandler.Unregister(self.npc)
	MotionController.Stop(self.npc)
	self.stateManager:Transition("Dead")

	if self.config.XPReward ~= nil and self.config.SilverReward ~= nil then
		local xpRoll = math.random(self.config.XPReward.Min, self.config.XPReward.Max)
		local silverRoll = math.random(self.config.SilverReward.Min, self.config.SilverReward.Max)
		EnemyDefeatedBridge.ProcessDeath(self.npc, xpRoll, silverRoll)
	end

	CleanupService.RegisterDead(self.npc)
end

function NPCController:Destroy()
	MotionController.Stop(self.npc)
	AIManager.Unregister(self.id)
	ZoneHandler.Unregister(self.npc)
	self.target = nil
	self.alive = false
end

return NPCController