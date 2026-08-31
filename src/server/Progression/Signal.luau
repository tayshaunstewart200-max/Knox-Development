local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if self.Connected == false then
		return
	end

	self.Connected = false
	local signal = self.Signal
	local index = table.find(signal.Listeners, self)
	if index ~= nil then
		table.remove(signal.Listeners, index)
	end
end

function Signal.New()
	local self = setmetatable({}, Signal)
	self.Listeners = {}
	return self
end

function Signal:Connect(listener)
	local connection = setmetatable({
		Listener = listener,
		Signal = self,
		Connected = true,
	}, Connection)

	table.insert(self.Listeners, connection)
	return connection
end

function Signal:Fire(...)
	for _, connection in ipairs(self.Listeners) do
		if connection.Connected then
			task.spawn(connection.Listener, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal