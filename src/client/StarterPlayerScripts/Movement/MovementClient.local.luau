local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer

local Modules = ReplicatedStorage.Movement.Modules
local MovementConfig = require(Modules.MovementConfig)
local StaminaService = require(Modules.StaminaService)
local SpeedController = require(Modules.SpeedController)
local MomentumController = require(Modules.MomentumController)
local CombatStateManager = require(ReplicatedStorage.SharedModules.CombatStateManager)
local AnimationController = require(player:WaitForChild("PlayerScripts").Combat.AnimationController)

local SprintAnim = ReplicatedStorage.Movement.Animations:FindFirstChild("Sprint")

local TOGGLE_COOLDOWN = 0.2

local character = nil
local humanoid = nil
local sprintToggled = false
local lastToggleTime = 0
local isSprinting = false
local heartbeatConnection = nil

local function StartSprint()
	if isSprinting then return end
	isSprinting = true
	StaminaService:StartDrain()
	if SprintAnim then AnimationController:Play(SprintAnim, "Sprint") end
end

local function StopSprint()
	if not isSprinting then return end
	isSprinting = false
	StaminaService:StopDrain()
	if SprintAnim then AnimationController:Stop(SprintAnim) end
end

local function UpdateMovement()
	if not humanoid then return end

	local isDepleted = StaminaService:IsDepleted()
	local isDead = CombatStateManager:Has(character, "Dead")
	local isStunned = CombatStateManager:Has(character, "Stunned")
	local isAttacking = CombatStateManager:Has(character, "Attacking")

	local shouldSprint = sprintToggled
		and humanoid.MoveDirection.Magnitude > 0.1
		and not isDepleted
		and not isDead
		and not isStunned
		and not isAttacking

	if shouldSprint then StartSprint() else StopSprint() end

	local speedTarget
	if isAttacking then
		speedTarget = "Attacking"
	elseif isSprinting and not isDepleted then
		speedTarget = "Sprint"
	else
		speedTarget = "Walk"
	end

	SpeedController:SetTarget(speedTarget, StaminaService:GetNormalized())
end

local function OnSprintAction(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then return end
	local now = os.clock()
	if now - lastToggleTime < TOGGLE_COOLDOWN then return end
	lastToggleTime = now
	sprintToggled = not sprintToggled
	return Enum.ContextActionResult.Sink
end

local function Cleanup()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

local function SetupCharacter(newCharacter)
	Cleanup()

	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
	humanoid:WaitForChild("Animator")
	isSprinting = false
	sprintToggled = false
	lastToggleTime = 0

	SpeedController:Setup(newCharacter)
	MomentumController:Setup(newCharacter)
	StaminaService:Cleanup()
	StaminaService:Start()
	AnimationController:Setup(newCharacter)

	heartbeatConnection = RunService.Heartbeat:Connect(UpdateMovement)
end

ContextActionService:BindAction("Sprint", OnSprintAction, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("Sprint", "Sprint")
ContextActionService:SetPosition("Sprint", UDim2.new(0.5, 0, 0.8, 0))

player.CharacterRemoving:Connect(Cleanup)
player.CharacterAdded:Connect(SetupCharacter)

if player.Character then
	SetupCharacter(player.Character)
end