local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ServerScriptService.Combat.Modules
local Remotes = ReplicatedStorage.Remotes.Combat

local CombatHandler = require(Modules.CombatHandler)
local ValidationService = require(Modules.ValidationService)
local RemoteGuard = require(Modules.RemoteGuard)

local M1Remote = Remotes:FindFirstChild("M1")
local ParryRemote = Remotes:FindFirstChild("Parry")
local DodgeRemote = Remotes:FindFirstChild("Dodge")
local PlayAnimation = Remotes:FindFirstChild("PlayAnimation")
local CombatEffect = Remotes:FindFirstChild("CombatEffect")
local StaggerRemote = Remotes:FindFirstChild("Stagger")

local REQUIRED_REMOTES = {
	M1 = M1Remote,
	Parry = ParryRemote,
	Dodge = DodgeRemote,
	PlayAnimation = PlayAnimation,
	CombatEffect = CombatEffect,
	Stagger = StaggerRemote,
}

local function VerifyRemotes()
	local allValid = true
	for name, remote in pairs(REQUIRED_REMOTES) do
		if not remote then
			warn(string.format("[CombatServer] CRITICAL: Remote '%s' is missing", name))
			allValid = false
		end
	end
	return allValid
end

local function SafeHandle(handler, player)
	local success, err = pcall(handler)
	if not success then
		warn(string.format("[CombatServer] Handler error for %s: %s",
			player and player.Name or "Unknown", tostring(err)))
	end
end

local function OnM1(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	if not ValidationService:ValidateM1(player) then return end
	SafeHandle(function() CombatHandler:HandleM1(player) end, player)
end

local function OnParry(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	if not ValidationService:ValidateParry(player) then return end
	SafeHandle(function() CombatHandler:HandleParry(player) end, player)
end

local function OnDodge(player, direction)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	if typeof(direction) ~= "Vector3" then return end
	if not ValidationService:ValidateDodge(player, direction) then return end
	SafeHandle(function() CombatHandler:HandleDodge(player, direction) end, player)
end

local function SetupPlayer(player)
	player.CharacterAdded:Connect(function(character)
		CombatHandler:Cleanup(player)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		humanoid.Died:Connect(function()
			SafeHandle(function() CombatHandler:HandleDeath(character, nil) end, player)
		end)
	end)
end

local function Initialize()
	if not VerifyRemotes() then
		error("[CombatServer] CRITICAL: One or more remotes missing. Aborting.")
		return
	end

	RemoteGuard:Wrap(M1Remote, OnM1)
	RemoteGuard:Wrap(ParryRemote, OnParry)
	RemoteGuard:Wrap(DodgeRemote, OnDodge)

	for _, player in ipairs(Players:GetPlayers()) do
		SetupPlayer(player)
	end

	Players.PlayerAdded:Connect(SetupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		SafeHandle(function()
			CombatHandler:Cleanup(player)
			ValidationService:Cleanup(player)
		end, player)
	end)

	print("[CombatServer] Initialized successfully")
end

Initialize()