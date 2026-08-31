local StateManager = {}
StateManager.__index = StateManager

local ALLOWED_TRANSITIONS = {
	Roam    = { Chase = true, Dead = true },
	Chase   = { Attack = true, Return = true, Roam = true, Dead = true },
	Attack  = { Chase = true, Return = true, Roam = true, Dead = true },
	Return  = { Roam = true, Chase = true, Dead = true },
	Dead    = {},
}

function StateManager.new(npc)
	local self = setmetatable({}, StateManager)
	self.npc = npc
	self.current = "Roam"
	self.previous = nil
	self.onTransition = nil
	return self
end

function StateManager:GetState()
	return self.current
end

function StateManager:CanTransition(toState)
	local transitions = ALLOWED_TRANSITIONS[self.current]
	return transitions ~= nil and transitions[toState] == true
end

function StateManager:Transition(toState)
	if self.current == toState then
		return false
	end
	if not self:CanTransition(toState) then
		return false
	end
	self.previous = self.current
	self.current = toState
	if self.onTransition then
		self.onTransition(self.npc, self.previous, toState)
	end
	return true
end

function StateManager:OnTransition(callback)
	self.onTransition = callback
end

function StateManager:IsDead()
	return self.current == "Dead"
end

function StateManager:Reset()
	self.current = "Roam"
	self.previous = nil
end

return StateManager