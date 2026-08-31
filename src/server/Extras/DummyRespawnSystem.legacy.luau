local CONFIG = {
	MaxHealth           = 100,
	StartHealth         = 100,
	RespawnDelay        = 5,
	RemoveCorpseOnDeath = true,
	CorpseRemoveDelay   = 0,
}

local Workspace  = game:GetService("Workspace")

local World       = Workspace:WaitForChild("World", 10)
local DummyModels = World and World:WaitForChild("DummyModels", 10)

if not DummyModels then
	error("[DummyRespawnSystem] Could not find Workspace.World.DummyModels — aborting.")
end

local activeConnections: { [Model]: { RBXScriptConnection } } = {}
local respawnPending: { [Model]: boolean } = {}

local function cloneTemplate(template: Model): Model
	local clone: Model = template:Clone()
	clone.Parent = DummyModels

	if template.PrimaryPart and clone.PrimaryPart then
		clone:SetPrimaryPartCFrame(template.PrimaryPart.CFrame)
	end

	return clone
end

local function configureHumanoid(humanoid: Humanoid)
	humanoid.MaxHealth          = CONFIG.MaxHealth
	humanoid.Health             = CONFIG.StartHealth
	humanoid.BreakJointsOnDeath = false
end

local function destroyRig(model: Model)
	for _, v in model:GetDescendants() do
		if v:IsA("Motor6D") or v:IsA("Weld") or v:IsA("WeldConstraint") then
			v:Destroy()
		end
	end
end

local setupDummy

setupDummy = function(template: Model, live: Model)
	local humanoid: Humanoid = live:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[DummyRespawnSystem] No Humanoid found in", live:GetFullName())
		return
	end

	configureHumanoid(humanoid)

	local connections: { RBXScriptConnection } = {}
	activeConnections[template] = connections

	local diedConn: RBXScriptConnection
	diedConn = humanoid.Died:Connect(function()
		if respawnPending[template] then return end
		respawnPending[template] = true

		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)

		if CONFIG.RemoveCorpseOnDeath then
			task.delay(CONFIG.CorpseRemoveDelay, function()
				destroyRig(live)
				live:Destroy()
			end)
		end

		task.delay(CONFIG.RespawnDelay, function()
			respawnPending[template] = nil

			if not template or not template.Parent then return end

			local newLive = cloneTemplate(template)
			setupDummy(template, newLive)
		end)
	end)

	table.insert(connections, diedConn)

	local ancestryConn: RBXScriptConnection
	ancestryConn = live.AncestryChanged:Connect(function(_, newParent)
		if newParent == nil then
			for _, c in connections do
				c:Disconnect()
			end
			table.clear(connections)
			activeConnections[template] = nil
		end
	end)

	table.insert(connections, ancestryConn)
end

local function initExisting()
	for _, model in DummyModels:GetChildren() do
		if model:IsA("Model") then
			local template: Model = model:Clone()
			template.Name         = model.Name .. "_Template"
			template.Parent       = script
			setupDummy(template, model)
		end
	end
end

local function onChildAdded(child: Instance)
	if not child:IsA("Model") then return end
	if child.Name:find("_Template$") then return end

	task.defer(function()
		if not child.Parent then return end

		local template: Model = child:Clone()
		template.Parent       = script
		setupDummy(template, child)
	end)
end

initExisting()
DummyModels.ChildAdded:Connect(onChildAdded)

print(string.format(
	"[DummyRespawnSystem] Watching %d Dummy(s) | HP: %d | Respawn: %.1fs",
	#DummyModels:GetChildren(),
	CONFIG.MaxHealth,
	CONFIG.RespawnDelay
	))