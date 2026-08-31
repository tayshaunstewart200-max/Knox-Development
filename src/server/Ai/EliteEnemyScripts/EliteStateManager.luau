local EliteStateManager = {}
EliteStateManager.__index = EliteStateManager

local MOVEMENT_STATES = {
	Idle = true,
	Patrol = true,
	Observe = true,
	Chase = true,
	Attack = true,
	Dead = true,
}

local COMBAT_STATES = {
	Combo = true,
	Heavy = true,
	Heal = true,
}

function EliteStateManager.new(npc)
	local self = setmetatable({}, EliteStateManager)
	self.npc = npc
	self.state = "Idle"
	self.combatState = nil
	self.combatLocked = false
	self.transitionCallbacks = {}
	self.combatCallbacks = {}
	return self
end

function EliteStateManager:GetState()
	return self.state
end

function EliteStateManager:GetCombatState()
	return self.combatState
end

function EliteStateManager:IsCombatLocked()
	return self.combatLocked
end

function EliteStateManager:OnTransition(callback)
	table.insert(self.transitionCallbacks, callback)
end

function EliteStateManager:OnCombatTransition(callback)
	table.insert(self.combatCallbacks, callback)
end

function EliteStateManager:Transition(newState)
	if self.state == "Dead" then
		return false
	end
	if not MOVEMENT_STATES[newState] then
		warn("EliteStateManager: invalid movement state", newState)
		return false
	end
	if self.combatLocked then
		return false
	end
	local oldState = self.state
	if oldState == newState then
		return false
	end
	self.state = newState
	for _, callback in ipairs(self.transitionCallbacks) do
		callback(self.npc, oldState, newState)
	end
	return true
end

function EliteStateManager:EnterCombat(combatState)
	if self.state ~= "Attack" then
		warn("EliteStateManager: EnterCombat called outside Attack state")
		return false
	end
	if not COMBAT_STATES[combatState] then
		warn("EliteStateManager: invalid combat state", combatState)
		return false
	end
	if self.combatLocked then
		return false
	end
	local oldCombatState = self.combatState
	self.combatState = combatState
	self.combatLocked = true
	for _, callback in ipairs(self.combatCallbacks) do
		callback(self.npc, oldCombatState, combatState)
	end
	return true
end

function EliteStateManager:FinishCombat()
	if not self.combatLocked then
		return false
	end
	local oldCombatState = self.combatState
	self.combatState = nil
	self.combatLocked = false
	for _, callback in ipairs(self.combatCallbacks) do
		callback(self.npc, oldCombatState, nil)
	end
	self:Transition("Observe")
	return true
end

function EliteStateManager:Kill()
	if self.state == "Dead" then
		return false
	end
	local oldState = self.state
	self.combatLocked = false
	self.combatState = nil
	self.state = "Dead"
	for _, callback in ipairs(self.transitionCallbacks) do
		callback(self.npc, oldState, "Dead")
	end
	return true
end

return EliteStateManager