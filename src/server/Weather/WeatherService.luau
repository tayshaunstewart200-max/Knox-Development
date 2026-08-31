local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local WeatherConfig = require(ReplicatedStorage.Weather.WeatherConfig)

local CONFIG = {
	LightingTweenTime = 3,
	CloudsSecondsPerCover = 14,
	CloudsMinTweenTime = 4,
}

local WeatherService = {}

local weatherFolder = ReplicatedStorage:WaitForChild("Weather")

local eventsFolder = weatherFolder:FindFirstChild("WeatherEvents")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "WeatherEvents"
	eventsFolder.Parent = weatherFolder
end

local weatherChanged = eventsFolder:FindFirstChild("WeatherChanged")
if not weatherChanged then
	weatherChanged = Instance.new("RemoteEvent")
	weatherChanged.Name = "WeatherChanged"
	weatherChanged.Parent = eventsFolder
end

local getCurrentWeatherRemote = eventsFolder:FindFirstChild("GetCurrentWeather")
if not getCurrentWeatherRemote then
	getCurrentWeatherRemote = Instance.new("RemoteFunction")
	getCurrentWeatherRemote.Name = "GetCurrentWeather"
	getCurrentWeatherRemote.Parent = eventsFolder
end

local effectsFolder = Workspace:FindFirstChild("WeatherEffects")
local soundsFolder = SoundService:FindFirstChild("Weather")
local clouds = Workspace.Terrain:WaitForChild("Clouds")

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
end

local currentWeather = nil
local currentWeatherStartTime = nil
local currentWeatherDuration = nil
local originalTransparency = {}
local activeTweens = {}

local instanceCache = {}

local function classifyInstance(instance)
	if instance:IsA("Sound") then
		return "Sound"
	end

	local hasEnabled = pcall(function()
		return instance.Enabled
	end)
	if hasEnabled then
		return "Enabled"
	end

	local hasTransparency = pcall(function()
		return instance.Transparency
	end)
	if hasTransparency then
		originalTransparency[instance] = instance.Transparency
		return "Transparency"
	end

	return "None"
end

local function getTargetInstances(folder, name)
	if not folder then
		return nil
	end

	local folderCache = instanceCache[folder]
	if not folderCache then
		folderCache = {}
		instanceCache[folder] = folderCache
	end

	local cached = folderCache[name]
	if cached then
		return cached
	end

	local target = folder:FindFirstChild(name)
	if not target then
		return nil
	end

	local list = table.create(8)
	list[1] = {instance = target, kind = classifyInstance(target)}
	for _, descendant in target:GetDescendants() do
		table.insert(list, {instance = descendant, kind = classifyInstance(descendant)})
	end

	folderCache[name] = list
	return list
end

local function untrackTween(tween)
	local index = table.find(activeTweens, tween)
	if index then
		table.remove(activeTweens, index)
	end
end

local function trackTween(tween)
	table.insert(activeTweens, tween)
	tween.Completed:Once(function()
		untrackTween(tween)
	end)
	return tween
end

local function cancelActiveTweens()
	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)
end

local function activateInstance(entry, active)
	local instance = entry.instance
	local kind = entry.kind

	if kind == "Sound" then
		if active then
			instance:Play()
		else
			instance:Stop()
		end
	elseif kind == "Enabled" then
		instance.Enabled = active
	elseif kind == "Transparency" then
		local targetTransparency = active and originalTransparency[instance] or 1
		local tween = TweenService:Create(instance, TweenInfo.new(CONFIG.LightingTweenTime), {Transparency = targetTransparency})
		trackTween(tween)
		tween:Play()
	end
end

local function setActiveByName(folder, name, active)
	local targets = getTargetInstances(folder, name)
	if not targets then
		return
	end

	for _, entry in targets do
		activateInstance(entry, active)
	end
end

local function applyLighting(data, weatherName, duration)
	local lightingData = data.Lighting

	local goals = {
		Ambient = lightingData.Ambient,
		OutdoorAmbient = lightingData.OutdoorAmbient,
		Brightness = lightingData.Brightness,
		FogColor = lightingData.FogColor,
		FogStart = lightingData.FogStart,
		FogEnd = lightingData.FogEnd,
	}

	local lightingTween = TweenService:Create(Lighting, TweenInfo.new(CONFIG.LightingTweenTime), goals)
	trackTween(lightingTween)
	lightingTween:Play()

	local atmosphereGoals = {
		Haze = lightingData.AtmosphereHaze,
		Density = lightingData.AtmosphereDensity,
	}

	local atmosphereTween = TweenService:Create(atmosphere, TweenInfo.new(CONFIG.LightingTweenTime), atmosphereGoals)
	trackTween(atmosphereTween)
	atmosphereTween:Play()

	local coverDistance = math.abs(data.CloudsCover - clouds.Cover)
	local cloudsTweenTime

	if weatherName == "Overcast" then
		cloudsTweenTime = duration or math.max(coverDistance * CONFIG.CloudsSecondsPerCover, CONFIG.CloudsMinTweenTime)
	else
		cloudsTweenTime = math.max(coverDistance * CONFIG.CloudsSecondsPerCover, CONFIG.CloudsMinTweenTime)
	end

	local cloudsEasingDirection = data.CloudsCover < clouds.Cover and Enum.EasingDirection.In or Enum.EasingDirection.Out
	local cloudsTween = TweenService:Create(clouds, TweenInfo.new(cloudsTweenTime, Enum.EasingStyle.Sine, cloudsEasingDirection), {Cover = data.CloudsCover})
	trackTween(cloudsTween)
	cloudsTween:Play()
end

function WeatherService.Apply(weatherName, duration)
	local visualWeatherName = weatherName == "Overcast" and "Cloudy" or weatherName
	local data = WeatherConfig.Data[visualWeatherName]
	if not data or weatherName == currentWeather then
		return
	end

	cancelActiveTweens()

	local previousWeather = currentWeather
	local previousData = previousWeather and WeatherConfig.Data[previousWeather == "Overcast" and "Cloudy" or previousWeather]

	currentWeather = weatherName
	currentWeatherStartTime = os.clock()
	currentWeatherDuration = duration

	if previousData then
		for _, effectName in previousData.Effects do
			setActiveByName(effectsFolder, effectName, false)
		end
		for _, soundName in previousData.Sounds do
			setActiveByName(soundsFolder, soundName, false)
		end
	end

	local lightingUnchanged = previousData ~= nil
		and previousData.Lighting == data.Lighting
		and previousData.CloudsCover == data.CloudsCover

	if not lightingUnchanged then
		applyLighting(data, weatherName, duration)
	end

	for _, effectName in data.Effects do
		setActiveByName(effectsFolder, effectName, true)
	end
	for _, soundName in data.Sounds do
		setActiveByName(soundsFolder, soundName, true)
	end

	weatherChanged:FireAllClients(weatherName, duration)
end

function WeatherService.GetCurrentWeather()
	if not currentWeather then
		return nil
	end

	local elapsed = os.clock() - currentWeatherStartTime
	local remaining = math.max(currentWeatherDuration - elapsed, 0)

	return currentWeather, remaining
end

getCurrentWeatherRemote.OnServerInvoke = function(player)
	return WeatherService.GetCurrentWeather()
end

return WeatherService