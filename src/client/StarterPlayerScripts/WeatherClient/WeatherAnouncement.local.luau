local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local weatherChanged = ReplicatedStorage:WaitForChild("Weather"):WaitForChild("WeatherEvents"):WaitForChild("WeatherChanged")

local MESSAGES = {
	Sunny = "The skies have cleared.",
	Cloudy = "Clouds gather overhead.",
	Rain = "Rain begins to fall.",
	Storm = "A thunderstorm rolls in.",
}

local CONFIG = {
	FadeInTime = 0.6,
	HoldTime = 4,
	FadeOutTime = 0.6,
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WeatherAnnouncement"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "AnnouncementLabel"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0.02, 0)
label.Size = UDim2.new(0, 500, 0, 24)
label.BackgroundTransparency = 1
label.Font = Enum.Font.Garamond
label.TextSize = 18
label.TextColor3 = Color3.fromRGB(250, 248, 240)
label.TextStrokeColor3 = Color3.fromRGB(35, 25, 15)
label.TextStrokeTransparency = 0.4
label.TextTransparency = 1
label.TextXAlignment = Enum.TextXAlignment.Center
label.TextYAlignment = Enum.TextYAlignment.Top
label.Text = ""
label.Parent = screenGui

local lastWeather = nil
local currentTween = nil
local currentThread = nil
local requestId = 0

local function playAnnouncement(myId, weatherName)
	local message = MESSAGES[weatherName]
	if not message then
		return
	end

	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	label.Text = message
	label.TextTransparency = 1

	local fadeIn = TweenService:Create(label, TweenInfo.new(CONFIG.FadeInTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0})
	currentTween = fadeIn
	fadeIn:Play()
	fadeIn.Completed:Wait()

	if requestId ~= myId then
		return
	end

	task.wait(CONFIG.HoldTime)

	if requestId ~= myId then
		return
	end

	local fadeOut = TweenService:Create(label, TweenInfo.new(CONFIG.FadeOutTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {TextTransparency = 1})
	currentTween = fadeOut
	fadeOut:Play()
end

weatherChanged.OnClientEvent:Connect(function(weatherName, duration)
	if weatherName == lastWeather then
		return
	end
	lastWeather = weatherName

	requestId += 1
	local myId = requestId

	if currentThread then
		task.cancel(currentThread)
	end
	currentThread = task.spawn(playAnnouncement, myId, weatherName)
end)