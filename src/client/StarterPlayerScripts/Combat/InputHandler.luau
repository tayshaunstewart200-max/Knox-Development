local InputHandler = {}

local ContextActionService = game:GetService("ContextActionService")

local callbacks = {}

local function Fire(action)
	if callbacks[action] then callbacks[action]() end
end

local function HandleAction(actionName, inputState)
	if inputState ~= Enum.UserInputState.Begin then return end
	Fire(actionName)
	return Enum.ContextActionResult.Sink
end

function InputHandler:OnAction(action, callback)
	callbacks[action] = callback
end

function InputHandler:Initialize()
	ContextActionService:BindAction("M1", HandleAction, true,
		Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	ContextActionService:BindAction("Parry", HandleAction, true,
		Enum.KeyCode.F, Enum.KeyCode.ButtonL1)

	ContextActionService:BindAction("Dodge", HandleAction, true,
		Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonA)

	ContextActionService:SetTitle("M1", "Atk")
	ContextActionService:SetTitle("Parry", "Parry")
	ContextActionService:SetTitle("Dodge", "Dodge")

	ContextActionService:SetPosition("M1", UDim2.new(0.8, 0, 0.2, 0))
	ContextActionService:SetPosition("Parry", UDim2.new(0.65, 0, 0.35, 0))
	ContextActionService:SetPosition("Dodge", UDim2.new(0.75, 0, 0.45, 0))
end

function InputHandler:Cleanup()
	ContextActionService:UnbindAction("M1")
	ContextActionService:UnbindAction("Parry")
	ContextActionService:UnbindAction("Dodge")
	callbacks = {}
end

return InputHandler