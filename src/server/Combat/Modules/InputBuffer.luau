local InputBuffer = {}

local BUFFER_WINDOW = 0.5
local buffers = {}

local function GetData(character)
	if not buffers[character] then
		buffers[character] = { buffered = false, action = nil, timer = nil }
	end
	return buffers[character]
end

local function CancelTimer(timer)
	if timer then pcall(task.cancel, timer) end
end

function InputBuffer:Buffer(character, action)
	if not character then return end
	local data = GetData(character)
	CancelTimer(data.timer)
	data.buffered = true
	data.action = action
	data.timer = task.delay(BUFFER_WINDOW, function()
		data.buffered = false
		data.action = nil
		data.timer = nil
	end)
end

function InputBuffer:Consume(character)
	if not character then return nil end
	local data = GetData(character)
	if not data.buffered then return nil end
	local action = data.action
	CancelTimer(data.timer)
	data.buffered = false
	data.action = nil
	data.timer = nil
	return action
end

function InputBuffer:HasBuffer(character)
	if not character then return false end
	return GetData(character).buffered
end

function InputBuffer:Cleanup(character)
	if not character then return end
	local data = buffers[character]
	if data then CancelTimer(data.timer) end
	buffers[character] = nil
end

return InputBuffer