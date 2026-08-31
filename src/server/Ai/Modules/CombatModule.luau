local CombatModule = {}
local CONFIG = {
	DAMAGE_DELAY = 0.3,
	ATTACK_RANGE_BUFFER = 5,
}
local cooldowns = {}
local function isInRange(npc, target, attackRange)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local character = target.Character
	if not character then return false end
	local targetRoot = character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return false end
	return (root.Position - targetRoot.Position).Magnitude <= (attackRange + CONFIG.ATTACK_RANGE_BUFFER)
end
local function isTargetAlive(target)
	local character = target.Character
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	return humanoid.Health > 0
end
function CombatModule.Attack(npc, target, config, onComplete)
	local id = npc
	if cooldowns[id] then
		return
	end
	if not isTargetAlive(target) then
		if onComplete then onComplete(false) end
		return
	end
	if not isInRange(npc, target, config.AttackRange) then
		if onComplete then onComplete(true) end
		return
	end
	local attackCooldown = config.AttackCooldown or 1.5
	cooldowns[id] = true
	task.delay(CONFIG.DAMAGE_DELAY, function()
		if not npc or not npc.Parent then
			cooldowns[id] = nil
			return
		end
		if isTargetAlive(target) and isInRange(npc, target, config.AttackRange) then
			local character = target.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:TakeDamage(config.Damage)
			end
		end
	end)
	task.delay(attackCooldown, function()
		cooldowns[id] = nil
		if npc and npc.Parent and onComplete then
			onComplete(isTargetAlive(target))
		end
	end)
end
function CombatModule.IsOnCooldown(npc)
	return cooldowns[npc] == true
end
function CombatModule.ClearCooldown(npc)
	cooldowns[npc] = nil
end
return CombatModule