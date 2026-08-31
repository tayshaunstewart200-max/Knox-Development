local Players = game:GetService("Players")

local ProfileService = require(script.Parent.ProfileService)
local ProgressionInit = require(script.Parent.ProgressionInit)

local function OnPlayerAdded(player)
	ProfileService.LoadProfile(player)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(OnPlayerAdded, player)
end

Players.PlayerAdded:Connect(OnPlayerAdded)