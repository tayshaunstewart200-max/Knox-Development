local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer

local Modules = ReplicatedStorage.Movement.Modules
local MovementConfig = require(Modules.MovementConfig)
local MovementStateResolver = require(Modules.MovementStateResolver)
local StaminaService = require(Modules.StaminaService)
local SpeedController = require(Modules.SpeedController)
local MomentumController = require(Modules.MomentumController)
local CombatStateManager = require(ReplicatedStorage.SharedModules.CombatStateManager)
local AnimationController = require(player:WaitForChild("PlayerScripts").Combat.AnimationController)

local SprintAnim = ReplicatedStorage.Movement.Animations:FindFirstChild("Sprint")

local TOGGLE_COOLDOWN = 0.2
local MOVEMENT_THRESHOLD = 0.1

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
	if not humanoid or not character then return end

	local policy = MovementStateResolver:Resolve(character, CombatStateManager)
	local isDepleted = StaminaService:IsDepleted()
	local hasMovementInput = humanoid.MoveDirection.Magnitude > MOVEMENT_THRESHOLD

	local shouldSprint = sprintToggled
		and hasMovementInput
		and policy.CanSprint
		and not isDepleted

	if shouldSprint then
		StartSprint()
	else
		StopSprint()
	end

	local speedTarget
	if not policy.CanMove then
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
	StopSprint()

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	MomentumController:Cleanup()
	SpeedController:Cleanup()
	StaminaService:Cleanup()

	character = nil
	humanoid = nil
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
