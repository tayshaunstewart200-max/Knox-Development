local CleanupService = {}

local CONFIG = {
	CLEANUP_DELAY = 4,
}

local pending = {}

function CleanupService.RegisterDead(npc)
	if pending[npc] then
		return
	end

	pending[npc] = true

	task.delay(CONFIG.CLEANUP_DELAY, function()
		pending[npc] = nil
		if npc and npc.Parent then
			npc:Destroy()
		end
	end)
end

function CleanupService.Cancel(npc)
	pending[npc] = nil
end

return CleanupService
