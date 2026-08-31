local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local weatherEvents = ReplicatedStorage:WaitForChild("Weather"):WaitForChild("WeatherEvents")
local weatherChanged = weatherEvents:WaitForChild("WeatherChanged")
local getCurrentWeatherRemote = weatherEvents:WaitForChild("GetCurrentWeather")

local CONFIG = {
	MinStrikeWait = 8,
	MaxStrikeWait = 25,
	MinFlashTime = 0.05,
	MaxFlashTime = 0.15,
	MinThunderDelay = 0.5,
	MaxThunderDelay = 3,
	DoubleFlashChance = 0.3,
	DoubleFlashGap = 0.08,
	FlashBrightness = 0.6,
}

local player = Players.LocalPlayer
local thunderSound = script:WaitForChild("thunderSound")

local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
if not colorCorrection then
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Parent = Lighting
end

local baselineBrightness = colorCorrection.Brightness
local isStorming = false
local activeThread = nil

local function randomRange(min, max)
	return min + math.random() * (max - min)
end

local function doFlash()
	colorCorrection.Brightness = CONFIG.FlashBrightness
	task.wait(randomRange(CONFIG.MinFlashTime, CONFIG.MaxFlashTime))
	colorCorrection.Brightness = baselineBrightness
	if math.random() < CONFIG.DoubleFlashChance then
		task.wait(CONFIG.DoubleFlashGap)
		colorCorrection.Brightness = CONFIG.FlashBrightness
		task.wait(randomRange(CONFIG.MinFlashTime, CONFIG.MaxFlashTime))
		colorCorrection.Brightness = baselineBrightness
	end
end

local function strike()
	doFlash()
	task.wait(randomRange(CONFIG.MinThunderDelay, CONFIG.MaxThunderDelay))
	if isStorming then
		thunderSound:Play()
	end
end

local function lightningLoop()
	while isStorming do
		task.wait(randomRange(CONFIG.MinStrikeWait, CONFIG.MaxStrikeWait))
		if isStorming then
			strike()
		end
	end
end

local function startLightning()
	if activeThread then
		return
	end
	activeThread = task.spawn(lightningLoop)
end

local function stopLightning()
	if activeThread then
		task.cancel(activeThread)
		activeThread = nil
	end
	colorCorrection.Brightness = baselineBrightness
end

weatherChanged.OnClientEvent:Connect(function(weatherName, duration)
	local storming = weatherName == "Storm"
	if storming == isStorming then
		return
	end
	isStorming = storming
	if storming then
		startLightning()
	else
		stopLightning()
	end
end)

local ok, weatherName = pcall(function()
	return getCurrentWeatherRemote:InvokeServer()
end)

if ok and weatherName == "Storm" then
	isStorming = true
	startLightning()
end