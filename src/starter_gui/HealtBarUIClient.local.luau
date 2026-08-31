local Players = game:GetService("Players")
local Tweens = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local cam = workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "CoreHUD"
gui.ResetOnSpawn = true
gui.Parent = lp:WaitForChild("PlayerGui")

local core = Instance.new("Frame")
core.Name = "Anchor"
core.Size = UDim2.new(0, 235, 0, 48)
core.Position = UDim2.new(1, -30, 0, 30)
core.AnchorPoint = Vector2.new(1, 0)
core.BackgroundTransparency = 1
core.Parent = gui

local pfp = Instance.new("ImageLabel")
pfp.Name = "UserIcon"
pfp.Size = UDim2.new(0, 45, 0, 45)
pfp.Position = UDim2.new(0, 0, 0.5, 0)
pfp.AnchorPoint = Vector2.new(0, 0.5)
pfp.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
pfp.Image = Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
pfp.ZIndex = 6
pfp.Parent = core

Instance.new("UICorner", pfp).CornerRadius = UDim.new(1, 0)
local pfpLine = Instance.new("UIStroke", pfp)
pfpLine.Color = Color3.fromRGB(0, 255, 230)
pfpLine.Thickness = 2

local track = Instance.new("Frame")
track.Name = "Track"
track.Size = UDim2.new(1, -53, 0, 27)
track.Position = UDim2.new(1, 0, 0.5, 0)
track.AnchorPoint = Vector2.new(1, 0.5)
track.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
track.ZIndex = 1
track.Parent = core

Instance.new("UICorner", track).CornerRadius = UDim.new(0, 8)
local trackLine = Instance.new("UIStroke", track)
trackLine.Color = Color3.fromRGB(50, 50, 65)
trackLine.Thickness = 1.4

local barRed = Instance.new("Frame")
barRed.Name = "Catchup"
barRed.Size = UDim2.new(1, 0, 1, 0)
barRed.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
barRed.BorderSizePixel = 0
barRed.ZIndex = 2
barRed.Parent = track
Instance.new("UICorner", barRed).CornerRadius = UDim.new(0, 8)

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(1, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
barFill.BorderSizePixel = 0
barFill.ClipsDescendants = true
barFill.ZIndex = 3
barFill.Parent = track
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 8)

local ThemeActive = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)), 
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(0, 255, 180)), 
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 255, 0))
})

local ThemeLow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 40)), 
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 110, 0))
})

local fillGrad = Instance.new("UIGradient", barFill)
fillGrad.Color = ThemeActive

local barShield = Instance.new("Frame")
barShield.Name = "Shield"
barShield.Size = UDim2.new(0, 0, 1, 0)
barShield.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
barShield.BackgroundTransparency = 0.3
barShield.BorderSizePixel = 0
barShield.ZIndex = 4
barShield.Parent = track
Instance.new("UICorner", barShield).CornerRadius = UDim.new(0, 8)

local sheen = Instance.new("Frame")
sheen.Name = "Sheen"
sheen.Size = UDim2.new(0, 56, 1, 0)
sheen.Position = UDim2.new(-0.3, 0, 0, 0)
sheen.BackgroundTransparency = 0
sheen.BorderSizePixel = 0
sheen.ZIndex = 5
sheen.Parent = barFill

local sheenGrad = Instance.new("UIGradient", sheen)
sheenGrad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
sheenGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.4), 
	NumberSequenceKeypoint.new(1, 1)
})

task.spawn(function()
	while true do
		sheen.Position = UDim2.new(-0.5, 0, 0, 0)
		local t = Tweens:Create(sheen, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {Position = UDim2.new(1.5, 0, 0, 0)})
		t:Play()
		t.Completed:Wait()
		task.wait(1.8)
	end
end)

local valText = Instance.new("TextLabel")
valText.Name = "Value"
valText.Size = UDim2.new(1, -11, 1, 0)
valText.Position = UDim2.new(0, 11, 0, 0)
valText.BackgroundTransparency = 1
valText.TextColor3 = Color3.fromRGB(255, 255, 255)
valText.Font = Enum.Font.GothamBlack
valText.TextSize = 10
valText.TextXAlignment = Enum.TextXAlignment.Left
valText.TextYAlignment = Enum.TextYAlignment.Center
valText.Text = "100 / 100"
valText.ZIndex = 7
valText.Parent = track

local textLine = Instance.new("UIStroke", valText)
textLine.Color = Color3.fromRGB(3, 3, 5)
textLine.Thickness = 1.7

local cacheHp = hum.Health
local lowActive = false
local pulse

local function spawnSparks()
	local ratio = barFill.Size.X.Scale
	local isLow = (hum.Health / hum.MaxHealth <= 0.25)
	for i = 1, 12 do
		local p = Instance.new("Frame")
		p.Size = UDim2.new(0, math.random(3, 6), 0, math.random(3, 6))
		p.Position = UDim2.new(ratio, math.random(-8, 8), 0.5, math.random(-11, 11))
		p.BackgroundColor3 = isLow and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(0, 255, 255)
		p.BorderSizePixel = 0
		p.ZIndex = 8
		p.Parent = track
		Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)

		Tweens:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(ratio, p.Position.X.Offset + math.random(-56, 34), 0.5, p.Position.Y.Offset + math.random(-45, 45)),
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 0, 0)
		}):Play()
		Debris:AddItem(p, 0.35)
	end
end

local function camKick(force)
	task.spawn(function()
		local t = os.clock()
		while os.clock() - t < 0.25 do
			cam.CFrame = cam.CFrame * CFrame.new(math.random(-force, force)/100, math.random(-force, force)/100, math.random(-force, force)/100)
			RunService.RenderStepped:Wait()
		end
	end)
end

local function pop(amt, heal)
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(0, 45, 0, 22)
	tag.Position = UDim2.new(barFill.Size.X.Scale, math.random(-14, 14), 0, -20)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.GothamBlack
	tag.TextSize = 15
	tag.ZIndex = 9
	tag.Parent = track
	tag.TextColor3 = heal and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(255, 0, 60)
	tag.Text = (heal and "+" or "-") .. math.floor(amt)

	local s = Instance.new("UIStroke", tag)
	s.Thickness = 1.7
	s.Color = Color3.fromRGB(0, 0, 0)

	tag:TweenPosition(UDim2.new(tag.Position.X.Scale, tag.Position.X.Offset, 0, -50), "Out", "Back", 0.45, true)
	Tweens:Create(tag, TweenInfo.new(0.45), {TextTransparency = 1, Rotation = math.random(-30, 30)}):Play()
	Debris:AddItem(tag, 0.45)
end

local function sync()
	local hp = math.clamp(hum.Health, 0, hum.MaxHealth)
	local mHp = hum.MaxHealth
	local ratio = hp / mHp

	valText.Text = math.floor(hp) .. " / " .. math.floor(mHp)

	if hp < cacheHp then
		local d = cacheHp - hp
		pop(d, false)
		spawnSparks()
		camKick(d > (mHp * 0.2) and 22 or 8)

		task.spawn(function()
			for i = 1, 5 do
				core.Position = UDim2.new(1, -30 + math.random(-12, 12), 0, 30 + math.random(-12, 12))
				barFill.BackgroundTransparency = math.random(0, 1) == 1 and 0.6 or 0
				task.wait(0.015)
			end
			core.Position = UDim2.new(1, -30, 0, 30)
			barFill.BackgroundTransparency = 0
		end)
	elseif hp > cacheHp then
		pop(hp - cacheHp, true)
		spawnSparks()
		barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Tweens:Create(barFill, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end

	if ratio <= 0.25 then
		if not lowActive then
			lowActive = true
			pulse = Tweens:Create(trackLine, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Color = Color3.fromRGB(255, 0, 0), Thickness = 4})
			pulse:Play()
		end
		fillGrad.Color = ThemeLow
		pfpLine.Color = Color3.fromRGB(255, 0, 40)
		pfp.Position = UDim2.new(0, math.random(-2, 2), 0.5, math.random(-2, 2))
	else
		if lowActive then
			lowActive = false
			if pulse then pulse:Cancel() end
			Tweens:Create(trackLine, TweenInfo.new(0.2), {Color = Color3.fromRGB(50, 50, 65), Thickness = 2}):Play()
		end
		fillGrad.Color = ThemeActive
		pfpLine.Color = Color3.fromRGB(0, 255, 230)
		pfp.Position = UDim2.new(0, 0, 0.5, 0)
	end

	Tweens:Create(barFill, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(ratio, 0, 1, 0)}):Play()

	task.delay(0.1, function()
		Tweens:Create(barRed, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(ratio, 0, 1, 0)}):Play()
	end)

	local sh = hum:GetAttribute("Shield") or 0
	local mSh = hum:GetAttribute("MaxShield") or 100
	Tweens:Create(barShield, TweenInfo.new(0.18), {Size = UDim2.new(sh > 0 and math.clamp(sh / mSh, 0, 1) or 0, 0, 1, 0)}):Play()

	cacheHp = hp
end

hum.HealthChanged:Connect(sync)
hum:GetAttributeChangedSignal("Shield"):Connect(sync)

sync()