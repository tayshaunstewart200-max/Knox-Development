local CombatHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerModules = script.Parent
local CombatStateManager = require(ReplicatedStorage.SharedModules.CombatStateManager)
local ComboService    = require(ServerModules.ComboService)
local HitboxService   = require(ServerModules.HitboxService)
local DamageService   = require(ServerModules.DamageService)
local KnockbackService = require(ServerModules.KnockbackService)
local StaggerService  = require(ServerModules.StaggerService)
local ParryService    = require(ServerModules.ParryService)
local DodgeService    = require(ServerModules.DodgeService)

local Remotes = ReplicatedStorage.Remotes.Combat

local MELEE = {
	ComboLength         = 3,
	AttackSpeed         = 1.0,
	WindupDuration      = 0.15,
	AttackStateDuration = 0.35,
	RecoveryDuration    = 0.4,
	AttackCooldown      = 0.4,
	Hitbox = {
		Size      = Vector3.new(6, 5, 6),
		Offset    = 3,
		ConeAngle = 0.3,
	},
	Animations = {
		[1] = "M1_1",
		[2] = "M1_2",
		[3] = "M1_3",
	},
}

local playerData: { [Player]: { lastAttackTime: number } } = {}
local charConnections: { [Player]: RBXScriptConnection } = {}

local function GetData(player: Player)
	if not playerData[player] then
		playerData[player] = { lastAttackTime = 0 }
	end
	return playerData[player]
end

local function FireAnimation(player: Player, animName: string?)
	if animName then
		Remotes.PlayAnimation:FireClient(player, animName)
	end
end

local function FireEffect(targets: { Model }, effectName: string, data: { [string]: any }?)
	for _, target in targets do
		local p = Players:GetPlayerFromCharacter(target)
		if p then
			Remotes.CombatEffect:FireClient(p, effectName, data or {})
		end
	end
end

local function HandleHits(character: Model, hits: {any}, step: number, player: Player)
	local isFinisher = ComboService:IsFinisher(character, step, MELEE.ComboLength)

	for _, hit in hits do
		if ParryService:CheckParry(character, hit.character) then
			FireEffect({ hit.character }, "ParrySuccess", {})
			FireEffect({ character },     "ParryStun",   {})
			ComboService:Reset(character)
			CombatStateManager:Remove(character, "Attacking")
			return
		end

		local damage, isCrit, reason = DamageService:Apply(character, hit.character, step)

		if reason == "hit" then
			if isFinisher then
				StaggerService:Apply(character, hit.character, "Finisher")
			else
				StaggerService:Apply(character, hit.character, nil)
			end

			local hitPlayer = Players:GetPlayerFromCharacter(hit.character)
			if hitPlayer then
				FireEffect({ hit.character }, "HitReceived", {
					damage     = damage,
					isCrit     = isCrit,
					isFinisher = isFinisher,
				})
			end

			FireEffect({ character }, "HitConfirm", { isCrit = isCrit })
		end
	end

	if isFinisher then
		ComboService:Reset(character)
	end
end

local function BeginRecovery(character: Model, player: Player)
	local recoveryDuration = MELEE.RecoveryDuration / MELEE.AttackSpeed
	ComboService:SetRecovery(character, true)

	task.delay(recoveryDuration, function()
		if not character or not character.Parent then return end
		ComboService:SetRecovery(character, false)
		CombatStateManager:Remove(character, "Attacking")
		local buffered = ComboService:Consume(character)
		if buffered == "M1" then
			CombatHandler:HandleM1(player)
		end
	end)
end

local function SetupCharacter(character: Model, player: Player)
	CombatStateManager:Cleanup(character)
	ComboService:Cleanup(character)
	ParryService:Cleanup(character)
	DodgeService:Cleanup(character)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.Died:Connect(function()
		CombatHandler:HandleDeath(character, nil)
	end)
end

local function SetupPlayer(player: Player)
	local conn = player.CharacterAdded:Connect(function(character: Model)
		task.defer(function()
			SetupCharacter(character, player)
		end)
	end)
	charConnections[player] = conn

	if player.Character then
		task.defer(function()
			SetupCharacter(player.Character, player)
		end)
	end
end

function CombatHandler:HandleM1(player: Player)
	local character = player.Character
	if not character then return end

	if not CombatStateManager:CanAct(character, "M1") then
		if ComboService:IsInRecovery(character) then
			ComboService:Buffer(character)
		end
		return
	end

	local data = GetData(player)
	local now  = tick()
	if (now - data.lastAttackTime) < MELEE.AttackCooldown then return end
	data.lastAttackTime = now

	local step = ComboService:Increment(character, MELEE.ComboLength)
	CombatStateManager:Add(character, "Attacking", MELEE.AttackStateDuration)
	FireAnimation(player, MELEE.Animations[step] or ("M1_" .. step))

	local windup = MELEE.WindupDuration / MELEE.AttackSpeed
	task.delay(windup, function()
		if not character or not character.Parent then return end
		if not CombatStateManager:Has(character, "Attacking") then return end
		local hits = HitboxService:GetHitsWithConfig(character, MELEE.Hitbox)
		HandleHits(character, hits, step, player)
		BeginRecovery(character, player)
	end)
end

function CombatHandler:HandleParry(player: Player)
	local character = player.Character
	if not character then return end
	if not ParryService:Attempt(character) then return end
	FireAnimation(player, "Parry")
	FireEffect({ character }, "ParryAttempt", {})
end

function CombatHandler:HandleDodge(player: Player, clientDirection: Vector3)
	local character = player.Character
	if not character then return end
	if not DodgeService:Attempt(player, clientDirection) then return end
	FireAnimation(player, "Dodge")
	FireEffect({ character }, "DodgeStart", {})
end

function CombatHandler:HandleDeath(targetCharacter: Model, attackerCharacter: Model?)
	if not targetCharacter then return end
	StaggerService:ApplyDeath(attackerCharacter, targetCharacter)
end

function CombatHandler:Cleanup(player: Player)
	local conn = charConnections[player]
	if conn then
		conn:Disconnect()
		charConnections[player] = nil
	end
	local character = player.Character
	if character then
		CombatStateManager:Cleanup(character)
		ComboService:Cleanup(character)
		ParryService:Cleanup(character)
		DodgeService:Cleanup(character)
	end
	playerData[player] = nil
end

for _, player in Players:GetPlayers() do
	SetupPlayer(player)
end

Players.PlayerAdded:Connect(SetupPlayer)

Players.PlayerRemoving:Connect(function(player: Player)
	CombatHandler:Cleanup(player)
end)

return CombatHandler