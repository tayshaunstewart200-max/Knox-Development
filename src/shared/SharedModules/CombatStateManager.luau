local CombatStateManager = {}

local Players = game:GetService("Players")

local VALID_STATES = {
	Attacking  = true,
	Stunned    = true,
	Parrying   = true,
	Dodging    = true,
	Invincible = true,
	GuardBreak = true,
	Dead       = true,
}

local ACTION_BLOCKERS = {
	M1        = { Attacking = true, Stunned = true, Dead = true, Dodging = true },
	Parry     = { Attacking = true, Parrying = true, Stunned = true, Dead = true },
	Dodge     = { Dodging = true, Stunned = true, Dead = true },
	TakeDamage = { Invincible = true, Dead = true },
}

local characterStates = {}
local stateTimers = {}

local function GetStates(character)
	if not characterStates[character] then
		characterStates[character] = {}
	end
	return characterStates[character]
end

local function CancelTimer(character, stateName)
	if stateTimers[character] and stateTimers[character][stateName] then
		pcall(task.cancel, stateTimers[character][stateName])
		stateTimers[character][stateName] = nil
	end
end

function CombatStateManager:Add(character, stateName, duration)
	if not character or not VALID_STATES[stateName] then return end
	local states = GetStates(character)
	states[stateName] = true
	if duration then
		if not stateTimers[character] then
			stateTimers[character] = {}
		end
		CancelTimer(character, stateName)
		stateTimers[character][stateName] = task.delay(duration, function()
			self:Remove(character, stateName)
		end)
	end
end

function CombatStateManager:Remove(character, stateName)
	if not character then return end
	GetStates(character)[stateName] = nil
	CancelTimer(character, stateName)
end

function CombatStateManager:Has(character, stateName)
	if not character then return false end
	return GetStates(character)[stateName] == true
end

function CombatStateManager:CanAct(character, action)
	if not character or not ACTION_BLOCKERS[action] then return false end
	local states = GetStates(character)
	for state in pairs(ACTION_BLOCKERS[action]) do
		if states[state] then return false end
	end
	return true
end

function CombatStateManager:GetAll(character)
	if not character then return {} end
	local copy = {}
	for state, value in pairs(GetStates(character)) do
		copy[state] = value
	end
	return copy
end

function CombatStateManager:Clear(character)
	if not character then return end
	if stateTimers[character] then
		for _, thread in pairs(stateTimers[character]) do
			pcall(task.cancel, thread)
		end
		stateTimers[character] = nil
	end
	characterStates[character] = {}
end

function CombatStateManager:Cleanup(character)
	CombatStateManager:Clear(character)
	characterStates[character] = nil
	stateTimers[character] = nil
end

Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	if character then
		CombatStateManager:Cleanup(character)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function(character)
		CombatStateManager:Cleanup(character)
	end)
end)

return CombatStateManager