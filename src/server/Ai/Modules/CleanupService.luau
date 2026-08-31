local CleanupService = {}

local CONFIG = {
	CLEANUP_DELAY = 4,
}

local pending = {}

function CleanupService.RegisterDead(npc)
	local id = npc.Name

	if pending[id] then
		return
	end

	pending[id] = true

	task.delay(CONFIG.CLEANUP_DELAY, function()
		pending[id] = nil
		if npc and npc.Parent then
			npc:Destroy()
		end
	end)
end

function CleanupService.Cancel(npc)
	pending[npc.Name] = nil
end

return CleanupService