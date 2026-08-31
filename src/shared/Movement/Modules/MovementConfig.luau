local MovementConfig = {}

MovementConfig.Speed = {
	Walk = 16,
	Sprint = 28,
	Attacking = 10,
	Depleted = 8,
	Acceleration = 3,
	Deceleration = 5,
}

MovementConfig.Stamina = {
	Max = 1000,
	SprintDrainRate = 18,
	RegenRate = 1000,
	RegenDelay = 1,
	DodgeCost = 25,
	DepletionThreshold = 10,
}

MovementConfig.Momentum = {
	TurnSpeed = 4,
	MinTurnThreshold = 0.1,
}

return MovementConfig