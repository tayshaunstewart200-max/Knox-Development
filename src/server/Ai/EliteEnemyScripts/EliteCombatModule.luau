local DamageService = require(script.Parent.Parent.Parent.Combat.Modules.DamageService)

local EliteCombatModule = {}

local function getTargetCharacterAndHumanoid(target)
	local character = target and target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return character, humanoid
end

local function isTargetAlive(targetHumanoid)
	return targetHumanoid ~= nil and targetHumanoid.Health > 0
end

local function isWithinInterruptRange(npc, target, config)
	local npcRoot = npc:FindFirstChild("HumanoidRootPart")
	local character = target and target.Character
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not npcRoot or not targetRoot then
		return false
	end
	local range = config.COMBAT_INTERRUPT_RANGE or config.AttackRange
	return (npcRoot.Position - targetRoot.Position).Magnitude <= range
end

local function runCombo(npc, target, config, token, onComplete)
	local hitCount = math.random(config.ComboHitCountMin, config.ComboHitCountMax)
	task.spawn(function()
		for hitIndex = 1, hitCount do
			if token.cancelled then
				onComplete(false)
				return
			end

			local targetCharacter, targetHumanoid = getTargetCharacterAndHumanoid(target)
			if not isTargetAlive(targetHumanoid) or not isWithinInterruptRange(npc, target, config) then
				task.wait(config.ComboHitInterval)
				onComplete(false)
				return
			end

			local multiplier = 1 + (hitIndex - 1) * config.ComboMultiplierStep
			local damage = config.Damage * multiplier
			DamageService:ApplyRaw(targetCharacter, damage)

			if token.cancelled or not isTargetAlive(targetHumanoid) then
				task.wait(config.ComboHitInterval)
				onComplete(false)
				return
			end

			if hitIndex < hitCount then
				task.wait(config.ComboHitInterval)
			end
		end
		onComplete(not token.cancelled)
	end)
end

local function runHeavy(npc, target, config, token, onComplete)
	task.spawn(function()
		local targetCharacter, targetHumanoid = getTargetCharacterAndHumanoid(target)
		if token.cancelled or not isTargetAlive(targetHumanoid) or not isWithinInterruptRange(npc, target, config) then
			onComplete(false)
			return
		end
		DamageService:ApplyRaw(targetCharacter, config.HeavyDamage)
		task.wait(config.HeavyAttackDuration or 0.8)
		onComplete(not token.cancelled and isTargetAlive(targetHumanoid))
	end)
end

local function runHeal(npc, config, token, onComplete)
	task.spawn(function()
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		if humanoid and not token.cancelled then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + config.HealAmount)
		end
		task.wait(config.HealDuration or 1)
		onComplete(not token.cancelled)
	end)
end

function EliteCombatModule.Execute(npc, target, action, config, token, onComplete)
	if action == "Combo" then
		runCombo(npc, target, config, token, onComplete)
	elseif action == "Heavy" then
		runHeavy(npc, target, config, token, onComplete)
	elseif action == "Heal" then
		runHeal(npc, config, token, onComplete)
	else
		warn("EliteCombatModule: unknown action", action)
		onComplete(false)
	end
end

return EliteCombatModule