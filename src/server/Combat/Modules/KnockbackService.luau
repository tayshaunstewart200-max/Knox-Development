local KnockbackService = {}

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local CombatStateManager = require(ReplicatedStorage.SharedModules.CombatStateManager)

local CONFIG = {
	Light    = { Force = 40,  Upward = 18, Duration = 0.3  },
	Heavy    = { Force = 65,  Upward = 25, Duration = 0.55 },
	Finisher = { Force = 55,  Upward = 22, Duration = 0.45 },
}

local MIN_SEPARATION = 0.5

function KnockbackService:Apply(attackerCharacter, targetCharacter, knockbackType)
	if not attackerCharacter or not targetCharacter then return end
	if CombatStateManager:Has(targetCharacter, "Dead") then return end

	local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart")
	local targetRoot   = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not targetRoot then return end

	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local profile = CONFIG[knockbackType] or CONFIG.Light

	local diff = Vector3.new(
		targetRoot.Position.X - attackerRoot.Position.X,
		0,
		targetRoot.Position.Z - attackerRoot.Position.Z
	)

	local horizontal: Vector3
	if diff.Magnitude >= MIN_SEPARATION then
		horizontal = diff.Unit
	else
		local look = attackerRoot.CFrame.LookVector
		horizontal = Vector3.new(look.X, 0, look.Z).Unit
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	targetRoot.AssemblyLinearVelocity = Vector3.new(
		horizontal.X * profile.Force,
		profile.Upward,
		horizontal.Z * profile.Force
	)
end

return KnockbackService