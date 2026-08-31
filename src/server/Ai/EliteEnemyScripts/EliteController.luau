local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local EliteAIManager = require(script.Parent.EliteAIManager)
local EliteBrain = require(script.Parent.EliteBrain)
local EliteMotionController = require(script.Parent.EliteMotionController)
local EliteCombatModule = require(script.Parent.EliteCombatModule)
local ZoneHandler = require(script.Parent.Parent.Modules.ZoneHandler)
local CleanupService = require(script.Parent.Parent.Modules.CleanupService)
local EnemyDefeatedBridge = require(ServerScriptService.Progression.EnemyDefeatedBridge)
local EliteController = {}
EliteController.__index = EliteController
function EliteController.new(npc, config)
	local self = setmetatable({}, EliteController)
	self.npc = npc
	self.config = config
	self.id = tostring(npc:GetAttribute("NpcId") or math.random(1, 999999))
	self.home = npc.HumanoidRootPart.Position
	self.alive = true
	self.combatToken = nil
	self.brain = EliteBrain.new(npc, config, self.home)
	self.brain:OnTransition(function(n, from, to)
		self:_onStateChanged(from, to)
	end)
	self.brain:OnCombatTransition(function(n, from, to)
		self:_onCombatStateChanged(from, to)
	end)
	self.brain:OnCommand(function(command)
		self:_onCommand(command)
	end)
	npc.Humanoid.Died:Once(function()
		self:OnDeath()
	end)
	npc.Humanoid.AttributeChanged:Connect(function(attributeName)
		self:_onAttributeChanged(attributeName)
	end)
	EliteAIManager.Register(self.id, self.brain, npc.HumanoidRootPart, config.DetectionRange)
	ZoneHandler.Register(npc, self.home, config.ZoneRadius)
	self.brain:Transition("Patrol")
	return self
end
function EliteController:_onCommand(command)
	if not self.alive then
		return
	end
	if command.Type == "MoveTo" then
		EliteMotionController.MoveTo(self.npc, command.Destination, self.config, command.OnReached)
	elseif command.Type == "StopAndFace" then
		EliteMotionController.Stop(self.npc)
		EliteMotionController.FaceTarget(self.npc, command.Target)
	end
end
function EliteController:_onStateChanged(from, to)
	if to == "Dead" then
		self:_enterDead()
	end
end
function EliteController:_onAttributeChanged(attributeName)
	if not self.alive then
		return
	end
	local userIdString = string.match(attributeName, "^DmgContrib_(%d+)$")
	if not userIdString then
		return
	end
	local player = Players:GetPlayerByUserId(tonumber(userIdString))
	if not player then
		return
	end
	self.brain:RecordHit(player)
end
function EliteController:_onCombatStateChanged(from, to)
	if not to then
		return
	end
	local target = self.brain:GetTarget()
	local token = { cancelled = false }
	self.combatToken = token
	EliteCombatModule.Execute(self.npc, target, to, self.config, token, function()
		if token.cancelled or not self.alive then
			return
		end
		self.brain:FinishCombat()
	end)
end
function EliteController:_enterDead()
	self.alive = false
	if self.combatToken then
		self.combatToken.cancelled = true
	end
	EliteMotionController.Stop(self.npc)
end
function EliteController:_getDamageContributions()
	local contributions = {}
	local total = 0
	for attributeName, value in pairs(self.npc.Humanoid:GetAttributes()) do
		local userIdString = string.match(attributeName, "^DmgContrib_(%d+)$")
		if userIdString and type(value) == "number" and value > 0 then
			contributions[tonumber(userIdString)] = value
			total += value
		end
	end
	return contributions, total
end
function EliteController:_grantRewards()
	local contributions, totalDamage = self:_getDamageContributions()
	if totalDamage <= 0 then
		return
	end
	local xpReward = self.config.XPReward
	local silverReward = self.config.SilverReward
	if not xpReward or not silverReward then
		return
	end
	local totalXP = math.random(xpReward.Min, xpReward.Max)
	local totalSilver = math.random(silverReward.Min, silverReward.Max)
	for userId, damage in pairs(contributions) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local share = damage / totalDamage
			EnemyDefeatedBridge.RewardEligible:Fire(player, math.floor(totalXP * share), math.floor(totalSilver * share))
		end
	end
end
function EliteController:OnDeath()
	if not self.alive then
		return
	end
	EliteAIManager.Unregister(self.id)
	ZoneHandler.Unregister(self.npc)
	self:_grantRewards()
	self.brain:Kill()
	CleanupService.RegisterDead(self.npc)
end
function EliteController:Destroy()
	EliteAIManager.Unregister(self.id)
	ZoneHandler.Unregister(self.npc)
	if self.combatToken then
		self.combatToken.cancelled = true
	end
	self.alive = false
	self.brain:Destroy()
	EliteMotionController.Stop(self.npc)
end
return EliteController