local EliteMemory = {}
EliteMemory.__index = EliteMemory

local CONFIG = {
	EXPIRY_DURATION = 300,
}

function EliteMemory.new(config)
	local self = setmetatable({}, EliteMemory)

	self.expiryDuration = (config and config.MEMORY_EXPIRY_DURATION) or CONFIG.EXPIRY_DURATION
	self.entries = {}

	return self
end

function EliteMemory:RecordHostile(userId)
	self.entries[userId] = {
		disposition = "Hostile",
		updatedAt = os.clock(),
	}
end

function EliteMemory:RecordPeaceful(userId)
	self.entries[userId] = {
		disposition = "Peaceful",
		updatedAt = os.clock(),
	}
end

function EliteMemory:GetDisposition(userId)
	local entry = self.entries[userId]
	if not entry then
		return nil
	end

	if os.clock() - entry.updatedAt > self.expiryDuration then
		self.entries[userId] = nil
		return nil
	end

	return entry.disposition
end

function EliteMemory:IsHostile(userId)
	return self:GetDisposition(userId) == "Hostile"
end

return EliteMemory