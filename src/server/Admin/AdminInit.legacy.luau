local Players = game:GetService("Players")

local AdminConfig = require(script.Parent.AdminConfig)
local AdminCommands = require(script.Parent.AdminCommands)

local COMMAND_HANDLERS = {
	setlevel = AdminCommands.SetLevel,
	setrank = AdminCommands.SetRank,
	setcurrency = AdminCommands.SetCurrency,
	addxp = AdminCommands.AddXP,
	resetprogression = AdminCommands.ResetProgression,
}

local function ParseCommand(message)
	if string.sub(message, 1, 1) ~= "/" then
		return nil
	end

	local parts = {}
	for part in string.gmatch(string.sub(message, 2), "%S+") do
		table.insert(parts, part)
	end

	if #parts == 0 then
		return nil
	end

	local commandName = string.lower(table.remove(parts, 1))
	return commandName, parts
end

local function OnChatted(player, message)
	if not AdminConfig.IsAdmin(player) then
		return
	end

	local commandName, args = ParseCommand(message)
	if commandName == nil then
		return
	end

	local handler = COMMAND_HANDLERS[commandName]
	if handler == nil then
		return
	end

	local success, result = handler(player, table.unpack(args))

	if success then
		print("[Admin]", player.Name, "->", result)
	else
		print("[Admin]", player.Name, "-> FAILED:", result)
	end
end

local function OnPlayerAdded(player)
	player.Chatted:Connect(function(message)
		OnChatted(player, message)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	OnPlayerAdded(player)
end

Players.PlayerAdded:Connect(OnPlayerAdded)