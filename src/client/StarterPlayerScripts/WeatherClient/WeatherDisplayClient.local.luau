local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local weatherEvents = ReplicatedStorage:WaitForChild("Weather"):WaitForChild("WeatherEvents")
local weatherChanged = weatherEvents:WaitForChild("WeatherChanged")
local getCurrentWeatherRemote = weatherEvents:WaitForChild("GetCurrentWeather")

local DISPLAY_NAMES = {
	Sunny = "Sunny",
	Cloudy = "Cloudy",
	Rain = "Rain",
	Storm = "Storm",
	Overcast = "Overcast",
}

local DISPLAY_COLORS = {
	Sunny = Color3.fromRGB(255, 255, 255),
	Cloudy = Color3.fromRGB(180, 180, 190),
	Rain = Color3.fromRGB(150, 200, 255),
	Storm = Color3.fromRGB(90, 90, 120),
	Overcast = Color3.fromRGB(200, 200, 200),
}

local CONFIG = {
	FadeOutTime = 0.15,
	FadeInTime = 0.25,
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local weatherUis = playerGui:WaitForChild("WeatherUis")
local weatherGui = weatherUis:WaitForChild("WeatherGui")
local weatherDisplay = weatherGui:WaitForChild("WeatherDisplay")

weatherDisplay.Font = Enum.Font.RobotoMono
weatherDisplay.TextSize = 12

local activeTween = nil

local function updateDisplay(weatherName)
	local displayName = DISPLAY_NAMES[weatherName]
	local color = DISPLAY_COLORS[weatherName]

	if not displayName or not color then
		warn("[WeatherDisplay] No display data for weather:", weatherName)
		return
	end

	if activeTween then
		activeTween:Cancel()
	end

	local fadeOut = TweenService:Create(weatherDisplay, TweenInfo.new(CONFIG.FadeOutTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {TextTransparency = 1})
	activeTween = fadeOut
	fadeOut:Play()

	fadeOut.Completed:Connect(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed then
			return
		end

		weatherDisplay.Text = "Weather: " .. displayName
		weatherDisplay.TextColor3 = color

		local fadeIn = TweenService:Create(weatherDisplay, TweenInfo.new(CONFIG.FadeInTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0})
		activeTween = fadeIn
		fadeIn:Play()
	end)
end

weatherChanged.OnClientEvent:Connect(function(weatherName, duration)
	updateDisplay(weatherName)
end)

local ok, weatherName = pcall(function()
	return getCurrentWeatherRemote:InvokeServer()
end)

if ok and weatherName then
	updateDisplay(weatherName)
else
	warn("[WeatherDisplay] Failed to get current weather:", weatherName)
end