local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeleeHandler = require(script.Parent.MeleeHandler)

local MeleeRemotes = ReplicatedStorage.Remotes.Melee
local MeleeM1      = MeleeRemotes.MeleeM1
local MeleeHitbox  = MeleeRemotes.MeleeHitbox

local M1_MIN_INTERVAL     = 0.35  
local HITBOX_MIN_INTERVAL = 0.1

local lastM1Time: { [Player]: number }     = {}
local lastHitboxTime: { [Player]: number } = {}

local charConnections: { [Player]: RBXScriptConnection } = {}

local function IsAlive(player: Player): boolean
	local char = player.Character
	if not char then return false end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function IsFlooding(tbl: { [Player]: number }, player: Player, minInterval: number): boolean
	local now = os.clock()
	local last = tbl[player]
	if last and (now - last) < minInterval then
		return true
	end
	tbl[player] = now
	return false
end

local function HasMeleeEquipped(player: Player): boolean
	local char = player.Character
	if not char then return false end
	for _, child in char:GetChildren() do
		if child:IsA("Tool") and child:FindFirstChild("IsMelee") then
			return true
		end
	end
	return false
end

MeleeM1.OnServerEvent:Connect(function(player: Player)
	if not IsAlive(player) then return end
	if not HasMeleeEquipped(player) then return end        
	if IsFlooding(lastM1Time, player, M1_MIN_INTERVAL) then return end

	MeleeHandler:HandleM1(player)
end)

MeleeHitbox.OnServerEvent:Connect(function(player: Player)
	if not IsAlive(player) then return end
	if not HasMeleeEquipped(player) then return end   
	if IsFlooding(lastHitboxTime, player, HITBOX_MIN_INTERVAL) then return end

	MeleeHandler:HandleHitbox(player)
end)

local function SetupPlayer(player: Player)
	local conn = player.CharacterAdded:Connect(function(character: Model)
		MeleeHandler:SetupCharacter(character, player)
	end)
	charConnections[player] = conn

	if player.Character then
		MeleeHandler:SetupCharacter(player.Character, player)
	end
end

local function CleanupPlayer(player: Player)
	local conn = charConnections[player]
	if conn then
		conn:Disconnect()
		charConnections[player] = nil
	end

	lastM1Time[player]     = nil
	lastHitboxTime[player] = nil

	MeleeHandler:Cleanup(player)
end

for _, player in Players:GetPlayers() do
	SetupPlayer(player)
end

Players.PlayerAdded:Connect(SetupPlayer)
Players.PlayerRemoving:Connect(CleanupPlayer)

print("[MeleeServer] Initialized")