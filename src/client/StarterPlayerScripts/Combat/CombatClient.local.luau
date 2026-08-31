local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local backpack  = player:WaitForChild("Backpack")

local Combat            = script.Parent
local InputHandler      = require(Combat.InputHandler)
local AnimationController = require(Combat.AnimationController)

local Remotes       = ReplicatedStorage.Remotes.Combat
local M1Remote      = Remotes.M1
local ParryRemote   = Remotes.Parry
local DodgeRemote   = Remotes.Dodge
local PlayAnimation = Remotes.PlayAnimation
local CombatEffect  = Remotes.CombatEffect
local StaggerRemote = Remotes.Stagger

local Animations = ReplicatedStorage.Combat.Animations

local ATTACK_COOLDOWN = 0.4

local localState = {
	attacking = false,
	parrying  = false,
	dodging   = false,
	stunned   = false,
	dead      = false,
}

local isMeleeEquipped = false
local equippedTool: Tool? = nil
local lastAttackTime  = 0

local charConnections: { RBXScriptConnection } = {}

local function DisconnectAll(tbl: { RBXScriptConnection })
	for _, conn in tbl do
		conn:Disconnect()
	end
	table.clear(tbl)
end

local function CanAct(action: string): boolean
	if localState.dead or localState.stunned then return false end

	if action == "M1" then
		if not isMeleeEquipped then return false end
		if localState.attacking or localState.dodging then return false end
		if (tick() - lastAttackTime) < ATTACK_COOLDOWN then return false end

	elseif action == "Parry" then
		if localState.parrying or localState.attacking then return false end

	elseif action == "Dodge" then
		if localState.dodging then return false end
	end

	return true
end

local function GetMoveDirection(): Vector3
	local hrp      = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return Vector3.zero end

	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude < 0.1 then
		return -hrp.CFrame.LookVector
	end
	return Vector3.new(moveDir.X, 0, moveDir.Z).Unit
end

local function IsMeleeTool(tool: Tool): boolean
	return tool.Name == "Melee" or tool:FindFirstChild("IsMelee") ~= nil
end

local function OnToolEquipped(tool: Tool)
	if IsMeleeTool(tool) then
		equippedTool   = tool
		isMeleeEquipped = true
	end
end

local function OnToolUnequipped(tool: Tool)
	if tool == equippedTool then
		equippedTool   = nil
		isMeleeEquipped = false
	end
end

local function ScanForMelee(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and IsMeleeTool(child :: Tool) then
			OnToolEquipped(child :: Tool)
			return
		end
	end
end

local function SetupToolTracking(char: Model)
	table.insert(charConnections, char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then OnToolEquipped(child :: Tool) end
	end))

	table.insert(charConnections, char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then OnToolUnequipped(child :: Tool) end
	end))

	ScanForMelee(char)
end

local function OnM1()
	if not CanAct("M1") then return end
	lastAttackTime   = tick()
	localState.attacking = true

	task.delay(ATTACK_COOLDOWN, function()
		localState.attacking = false
	end)

	M1Remote:FireServer()
end

local function OnParry()
	if not CanAct("Parry") then return end
	localState.parrying = true

	local anim = Animations:FindFirstChild("Parry")
	if anim then AnimationController:Play(anim, "Parry") end

	task.delay(0.35, function()
		localState.parrying = false
	end)

	ParryRemote:FireServer()
end

local function OnDodge()
	if not CanAct("Dodge") then return end
	localState.dodging = true

	local direction = GetMoveDirection()
	local anim      = Animations:FindFirstChild("Dodge")
	if anim then AnimationController:Play(anim, "Dodge") end

	task.delay(0.6, function()
		localState.dodging = false
	end)

	DodgeRemote:FireServer(direction)
end

local function OnCombatEffect(effectName: string, _data: any?)
	if effectName == "HitConfirm" then

	elseif effectName == "HitReceived" then

	elseif effectName == "ParrySuccess" then

	elseif effectName == "ParryStun" then

	elseif effectName == "DodgeStart" then
	end
end

local function OnStagger(staggerType: string, duration: number?)
	if staggerType == "Stagger" then
		localState.stunned = true
		task.delay(duration or 0, function()
			localState.stunned = false
		end)

	elseif staggerType == "Death" then
		localState.dead = true
		AnimationController:StopAll()
	end
end

local function SetupCharacter(newCharacter: Model)
	DisconnectAll(charConnections)

	character     = newCharacter
	isMeleeEquipped = false
	equippedTool  = nil
	lastAttackTime = 0
	localState    = {
		attacking = false,
		parrying  = false,
		dodging   = false,
		stunned   = false,
		dead      = false,
	}

	AnimationController:Setup(newCharacter)
	SetupToolTracking(newCharacter)
end

PlayAnimation.OnClientEvent:Connect(function(animName: string)
	local category = animName:match("^(M%d+)") or animName:match("^(%a+)")
	local anim     = Animations:FindFirstChild(animName)
	if not anim then
		warn("[CombatClient] Animation not found:", animName)
		return
	end
	AnimationController:Play(anim, category)
end)

CombatEffect.OnClientEvent:Connect(OnCombatEffect)
StaggerRemote.OnClientEvent:Connect(OnStagger)

InputHandler:OnAction("M1",    OnM1)
InputHandler:OnAction("Parry", OnParry)
InputHandler:OnAction("Dodge", OnDodge)

player.CharacterAdded:Connect(SetupCharacter)
SetupCharacter(character)
InputHandler:Initialize()