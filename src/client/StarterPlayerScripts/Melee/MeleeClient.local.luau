local Players              = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local MeleeRemotes = ReplicatedStorage.Remotes.Melee
local MeleeM1      = MeleeRemotes.MeleeM1
local MeleeHitbox  = MeleeRemotes.MeleeHitbox
local MeleeAnim    = MeleeRemotes.MeleeAnim

local Animations = ReplicatedStorage.Combat.Animations

local ATTACK_COOLDOWN = 0.4  
local HIT_DELAY       = 0.15 

local isMeleeEquipped = false
local equippedTool    = nil
local lastAttackTime  = 0
local isAttacking     = false
local animator: Animator? = nil

local charConnections: { RBXScriptConnection } = {}

local function DisconnectAll(tbl: { RBXScriptConnection })
	for _, conn in tbl do
		conn:Disconnect()
	end
	table.clear(tbl)
end

local function GetAnimator(char: Model): Animator?
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	return humanoid:WaitForChild("Animator", 5) :: Animator?
end

local function PlayAnim(animName: string)
	local hitboxFired = false

	local function FireHitbox()
		if hitboxFired then return end
		hitboxFired = true
		MeleeHitbox:FireServer()
	end

	task.delay(HIT_DELAY, FireHitbox)

	if not animator then return end

	local animObj = Animations:FindFirstChild(animName)
	if not animObj then
		warn("[MeleeClient] Animation not found:", animName)
		return
	end

	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animObj)
	end)
	if not ok or not track then return end

	track:Play(0.1)

	local markerConn: RBXScriptConnection
	markerConn = track:GetMarkerReachedSignal("Hit"):Connect(function()
		markerConn:Disconnect()
		FireHitbox()
	end)

	local stopConn: RBXScriptConnection
	stopConn = track.Stopped:Connect(function()
		stopConn:Disconnect()
		markerConn:Disconnect()
	end)
end

local function IsMeleeTool(tool: Tool): boolean
	return tool:FindFirstChild("IsMelee") ~= nil
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

local function SetupCharacter(char: Model)
	DisconnectAll(charConnections)

	character       = char
	isAttacking     = false
	lastAttackTime  = 0
	isMeleeEquipped = false
	equippedTool    = nil
	animator        = GetAnimator(char)

	table.insert(charConnections, char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then OnToolEquipped(child) end
	end))

	table.insert(charConnections, char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then OnToolUnequipped(child) end
	end))

	for _, child in char:GetChildren() do
		if child:IsA("Tool") then
			OnToolEquipped(child)
			break
		end
	end
end

local function OnM1Action(_name: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then return end
	if not isMeleeEquipped then return end
	if isAttacking then return end

	local now = tick()
	if (now - lastAttackTime) < ATTACK_COOLDOWN then return end

	lastAttackTime = now
	isAttacking    = true

	task.delay(ATTACK_COOLDOWN, function()
		isAttacking = false
	end)

	MeleeM1:FireServer()

	return Enum.ContextActionResult.Sink
end

MeleeAnim.OnClientEvent:Connect(function(animName: string)
	PlayAnim(animName)
end)

ContextActionService:BindAction(
	"MeleeM1",
	OnM1Action,
	false,
	Enum.UserInputType.MouseButton1,
	Enum.KeyCode.ButtonR2
)

player.CharacterAdded:Connect(SetupCharacter)
SetupCharacter(character)

print("[MeleeClient] Initialized")