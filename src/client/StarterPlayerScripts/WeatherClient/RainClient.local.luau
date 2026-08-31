local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local weatherAssets = ReplicatedStorage:WaitForChild("Weather"):WaitForChild("Assets")
local weatherEvents = ReplicatedStorage.Weather:WaitForChild("WeatherEvents")
local weatherChanged = weatherEvents:WaitForChild("WeatherChanged")
local getCurrentWeatherRemote = weatherEvents:WaitForChild("GetCurrentWeather")
local rainParticlesTemplate = weatherAssets:WaitForChild("rainParticles")

local CONFIG = {
	Height = 60,
	Size = Vector3.new(100, 0.5, 100),
	RainOnRate = 300,
	RainOnVolume = 0.1,
	RampInTime = 30,
	RampOutTime = 20,
	UpdateInterval = 0.25,
}

local player = Players.LocalPlayer

local rainFolder = Workspace:FindFirstChild("rainFolder")
if not rainFolder then
	rainFolder = Instance.new("Folder")
	rainFolder.Name = "rainFolder"
	rainFolder.Parent = Workspace
end

local existingRainPart = rainFolder:FindFirstChild("rainPart")
if existingRainPart then
	existingRainPart:Destroy()
end

local rainPart = Instance.new("Part")
rainPart.Name = "rainPart"
rainPart.Size = CONFIG.Size
rainPart.Anchored = true
rainPart.CanCollide = false
rainPart.CanQuery = false
rainPart.Transparency = 1
rainPart.Parent = rainFolder

local rainParticles = rainParticlesTemplate:Clone()
rainParticles.Enabled = false
rainParticles.Parent = rainPart

local rainSound = script:WaitForChild("rainSound")

local isRaining = false
local isInside = false
local activeVolumeTween = nil
local rainGeneration = 0
local updateLoopRunning = false

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function updateRainPart()
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local position = root.Position
	rainPart.Position = Vector3.new(position.X, position.Y + CONFIG.Height, position.Z)

	params.FilterDescendantsInstances = {character, rainPart}
	local raycastResult = Workspace:Raycast(position, Vector3.new(0, 10000, 0), params)
	local nowInside = raycastResult ~= nil and raycastResult.Instance.Transparency < 1

	if nowInside ~= isInside then
		isInside = nowInside
		rainParticles.Enabled = isRaining and not isInside
	end
end

local function runUpdateLoop(myGeneration)
	updateLoopRunning = true
	while isRaining and myGeneration == rainGeneration do
		updateRainPart()
		task.wait(CONFIG.UpdateInterval)
	end
	updateLoopRunning = false
end

local function setRaining(raining)
	if raining == isRaining then
		return
	end

	isRaining = raining
	rainGeneration += 1
	local myGeneration = rainGeneration

	if activeVolumeTween then
		activeVolumeTween:Cancel()
		activeVolumeTween = nil
	end

	local rampTime = raining and CONFIG.RampInTime or CONFIG.RampOutTime

	if raining then
		isInside = false
		rainSound:Play()
		if not updateLoopRunning then
			task.spawn(runUpdateLoop, myGeneration)
		end
	end

	TweenService:Create(rainParticles, TweenInfo.new(rampTime), {Rate = raining and CONFIG.RainOnRate or 0}):Play()

	local volumeTween = TweenService:Create(rainSound, TweenInfo.new(rampTime), {Volume = raining and CONFIG.RainOnVolume or 0})
	activeVolumeTween = volumeTween
	volumeTween:Play()

	if not raining then
		volumeTween.Completed:Connect(function()
			if myGeneration ~= rainGeneration then
				return
			end
			rainSound:Stop()
		end)
	end

	rainParticles.Enabled = raining and not isInside
end

weatherChanged.OnClientEvent:Connect(function(weatherName, duration)
	setRaining(weatherName == "Rain" or weatherName == "Storm")
end)

local ok, weatherName = pcall(function()
	return getCurrentWeatherRemote:InvokeServer()
end)
if ok and weatherName then
	setRaining(weatherName == "Rain" or weatherName == "Storm")
end