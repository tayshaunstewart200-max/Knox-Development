local ComboService = {}

local INPUT_WINDOW = 1.5
local comboData = {}

local function GetData(character)
	if not comboData[character] then
		comboData[character] = {
			step = 0,
			timer = nil,
			inRecovery = false,
			bufferedInput = false,
		}
	end
	return comboData[character]
end

local function CancelTimer(timer)
	if timer then pcall(task.cancel, timer) end
end

local function StartResetTimer(character)
	local data = GetData(character)
	CancelTimer(data.timer)
	data.timer = task.delay(INPUT_WINDOW, function()
		ComboService:Reset(character)
	end)
end

function ComboService:Increment(character, maxCombo)
	if not character then return nil end
	local data = GetData(character)
	data.step = (data.step % (maxCombo or 3)) + 1
	StartResetTimer(character)
	return data.step
end

function ComboService:IsFinisher(character, step, maxCombo)
	return step == (maxCombo or 3)
end

function ComboService:SetRecovery(character, state)
	GetData(character).inRecovery = state
end

function ComboService:IsInRecovery(character)
	return GetData(character).inRecovery
end

function ComboService:GetStep(character)
	if not character then return 0 end
	return GetData(character).step
end

function ComboService:Consume(character)
	local data = GetData(character)
	if not data.bufferedInput then return nil end
	data.bufferedInput = false
	return "M1"
end

function ComboService:Buffer(character)
	if not character then return end
	GetData(character).bufferedInput = true
end

function ComboService:Reset(character)
	if not character then return end
	local data = GetData(character)
	CancelTimer(data.timer)
	data.step = 0
	data.inRecovery = false
	data.bufferedInput = false
end

function ComboService:Cleanup(character)
	if not character then return end
	local data = comboData[character]
	if data then CancelTimer(data.timer) end
	comboData[character] = nil
end

return ComboService