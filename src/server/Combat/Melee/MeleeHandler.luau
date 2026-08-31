local MeleeHandler = {}

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatStateManager = require(ReplicatedStorage.SharedModules.CombatStateManager)
local CombatModules      = ServerScriptService.Combat.Modules
local DamageService  = require(CombatModules.DamageService)
local StaggerService = require(CombatModules.StaggerService)
local ParryService       = require(CombatModules.ParryService)

local MeleeAnim = ReplicatedStorage.Remotes.Melee.MeleeAnim

local CONFIG = {
	ComboLength         = 3,
	AttackCooldown      = 0.4,
	AttackStateDuration = 0.35,
	RecoveryDuration    = 0.4,
	ComboResetDelay     = 1.5,
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

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local playerData: { [Player]: { [string]: any } } = {}

local function GetData(player: Player)
	if not playerData[player] then
		playerData[player] = {
			step          = 0,
			inRecovery    = false,
			buffered      = false,
			comboTimer    = nil,
			recoveryTimer = nil,
			lastAttack    = 0,
			diedConn      = nil,
		}
	end
	return playerData[player]
end

local function CancelThread(t: thread?): nil
	if t then pcall(task.cancel, t) end
	return nil
end

local function ResetCombo(player: Player)
	local d = playerData[player]
	if not d then return end
	d.comboTimer    = CancelThread(d.comboTimer)
	d.recoveryTimer = CancelThread(d.recoveryTimer)
	d.step          = 0
	d.inRecovery    = false
	d.buffered      = false
end

local function GetHits(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return {} end

	overlapParams.FilterDescendantsInstances = { character }

	local hitboxCF = root.CFrame * CFrame.new(0, 0, -CONFIG.Hitbox.Offset)
	local parts    = workspace:GetPartBoundsInBox(hitboxCF, CONFIG.Hitbox.Size, overlapParams)
	local lookVec  = root.CFrame.LookVector
	local rootPos  = root.Position

	local hits = {}
	local seen: { [Model]: boolean } = {}

	for _, part in parts do
		local target = part.Parent :: Model
		if seen[target] or target == character then continue end
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end
		local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not targetRoot then continue end
		local toTarget = targetRoot.Position - rootPos
		if toTarget.Magnitude < 0.001 then continue end
		if lookVec:Dot(toTarget.Unit) < CONFIG.Hitbox.ConeAngle then continue end
		seen[target] = true
		table.insert(hits, { character = target, humanoid = humanoid })
	end

	return hits
end

local function HandleHits(attacker: Model, player: Player, hits: {any}, step: number)
	local isFinisher = step == CONFIG.ComboLength

	for _, hit in hits do
		if ParryService:CheckParry(attacker, hit.character) then
			ResetCombo(player)
			CombatStateManager:Remove(attacker, "Attacking")
			return
		end

		local _, _, reason = DamageService:Apply(attacker, hit.character, step)

		if reason == "hit" then
			if isFinisher then
				StaggerService:Apply(attacker, hit.character, "Finisher")
			else
				StaggerService:Apply(attacker, hit.character, nil)
			end
		end
	end

	if isFinisher then
		ResetCombo(player)
	end
end

local function BeginRecovery(character: Model, player: Player)
	local d = GetData(player)
	d.inRecovery = true

	d.recoveryTimer = task.delay(CONFIG.RecoveryDuration, function()
		d.recoveryTimer = nil
		if not character.Parent then return end
		d.inRecovery = false
		CombatStateManager:Remove(character, "Attacking")
		if d.buffered then
			d.buffered = false
			MeleeHandler:HandleM1(player)
		end
	end)
end

function MeleeHandler:HandleM1(player: Player)
	local character = player.Character
	if not character then return end

	if not CombatStateManager:CanAct(character, "M1") then
		local d = GetData(player)
		if d.inRecovery then
			d.buffered = true
		end
		return
	end

	local now = os.clock()
	local d   = GetData(player)

	if (now - d.lastAttack) < CONFIG.AttackCooldown then return end
	d.lastAttack = now

	d.step = (d.step % CONFIG.ComboLength) + 1
	local step = d.step

	d.comboTimer = CancelThread(d.comboTimer)
	d.comboTimer = task.delay(CONFIG.ComboResetDelay, function()
		d.comboTimer = nil
		ResetCombo(player)
	end)

	CombatStateManager:Add(character, "Attacking", CONFIG.AttackStateDuration)
	MeleeAnim:FireClient(player, CONFIG.Animations[step])

	BeginRecovery(character, player)
end

function MeleeHandler:HandleHitbox(player: Player)
	local character = player.Character
	if not character then return end
	if not CombatStateManager:Has(character, "Attacking") then return end
	local d    = GetData(player)
	local hits = GetHits(character)
	HandleHits(character, player, hits, d.step)
end

function MeleeHandler:SetupCharacter(character: Model, player: Player)
	ResetCombo(player)
	CombatStateManager:Cleanup(character)

	local d = GetData(player)

	if d.diedConn then
		d.diedConn:Disconnect()
		d.diedConn = nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	d.diedConn = humanoid.Died:Connect(function()
		d.diedConn = nil
		CombatStateManager:Add(character, "Dead")
		ResetCombo(player)
	end)
end

function MeleeHandler:Cleanup(player: Player)
	local d = playerData[player]
	if d then
		CancelThread(d.comboTimer)
		CancelThread(d.recoveryTimer)
		if d.diedConn then
			d.diedConn:Disconnect()
		end
	end
	playerData[player] = nil
	local character = player.Character
	if character then
		CombatStateManager:Cleanup(character)
		ParryService:Cleanup(character)
	end
end

return MeleeHandler