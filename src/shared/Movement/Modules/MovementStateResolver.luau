local MovementStateResolver = {}

local DEFAULT_POLICY = {
	CanMove = true,
	CanRotate = true,
	CanSprint = true,
	CanJump = true,
}

local STATE_POLICIES = {
	Attacking = { CanSprint = false, CanJump = false },
	Parrying = { CanSprint = false, CanJump = false },
	Dead = { CanMove = false, CanRotate = false, CanSprint = false, CanJump = false },
	Stunned = { CanMove = false, CanRotate = false, CanSprint = false, CanJump = false },
	GuardBreak = { CanMove = false, CanRotate = false, CanSprint = false, CanJump = false },
}

function MovementStateResolver:Resolve(character, combatStateManager)
	local result = table.clone(DEFAULT_POLICY)
	if not character or not combatStateManager then return result end

	for stateName, policy in pairs(STATE_POLICIES) do
		if combatStateManager:Has(character, stateName) then
			for key, value in pairs(policy) do
				if value == false then result[key] = false end
			end
		end
	end

	return result
end

return MovementStateResolver
