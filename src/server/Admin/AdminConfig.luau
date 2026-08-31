local AdminConfig = {}

AdminConfig.Whitelist = {
	[4892998937] = true,
}

function AdminConfig.IsAdmin(player)
	return AdminConfig.Whitelist[player.UserId] == true
end

return AdminConfig