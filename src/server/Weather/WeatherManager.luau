local WeatherManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeatherConfig = require(ReplicatedStorage.Weather.WeatherConfig)

local ENV_CONFIG = {
	UpdateIntervalMin = 180,
	UpdateIntervalMax = 300,
	DriftStep = 0.05,
	MomentumDecay = 0.95,
	MinDuration = 240,
}

local WEATHER_CONDITIONS = {
	Sunny = function(env)
		return env.Cloudiness < 0.3
	end,
	Cloudy = function(env)
		return env.Cloudiness >= 0.2 and env.Cloudiness < 0.75
	end,
	Rain = function(env)
		return env.Cloudiness >= 0.55 and env.Moisture >= 0.5 and env.StormPotential < 0.7
	end,
	Storm = function(env)
		return env.Cloudiness >= 0.7 and env.Moisture >= 0.65 and env.StormPotential >= 0.6
	end,
}

local WEATHER_ORDER = { "Sunny", "Cloudy", "Rain", "Storm" }

local WEATHER_NEIGHBORS = {}
for i, name in WEATHER_ORDER do
	WEATHER_NEIGHBORS[name] = {}
	if WEATHER_ORDER[i - 1] then
		table.insert(WEATHER_NEIGHBORS[name], WEATHER_ORDER[i - 1])
	end
	if WEATHER_ORDER[i + 1] then
		table.insert(WEATHER_NEIGHBORS[name], WEATHER_ORDER[i + 1])
	end
end

local WEATHER_DURATION = {
	Sunny = 480,
	Cloudy = 420,
	Rain = 360,
	Storm = 240,
}

local env = {
	Cloudiness = 0.2,
	Moisture = 0.15,
	Pressure = 0.7,
	StormPotential = 0.05,
}

local trend = {
	Cloudiness = 0,
	Moisture = 0,
	Pressure = 0,
}

local currentWeather = "Sunny"
local weatherStartTime = os.clock()

local function clamp01(n)
	return math.clamp(n, 0, 1)
end

local function driftValue(key)
	local randomShift = (math.random() - 0.5) * ENV_CONFIG.DriftStep * 2
	trend[key] = trend[key] * ENV_CONFIG.MomentumDecay + randomShift * (1 - ENV_CONFIG.MomentumDecay)
	env[key] = clamp01(env[key] + trend[key])
end

local function updateStormPotential()
	local target = ((1 - env.Pressure) * 0.4) + (env.Moisture * 0.35) + (env.Cloudiness * 0.25)
	local noise = (math.random() - 0.5) * 0.03
	env.StormPotential = clamp01(env.StormPotential + (target - env.StormPotential) * 0.15 + noise)
end

local function updateEnvironment()
	driftValue("Cloudiness")
	driftValue("Moisture")
	driftValue("Pressure")
	updateStormPotential()
end

local function getValidWeathers()
	local reachable = WEATHER_NEIGHBORS[currentWeather] or {}
	local valid = {}

	for _, name in reachable do
		if WEATHER_CONDITIONS[name](env) then
			table.insert(valid, name)
		end
	end

	if WEATHER_CONDITIONS[currentWeather](env) then
		table.insert(valid, currentWeather)
	end

	if #valid == 0 then
		table.insert(valid, currentWeather)
	end

	return valid
end

function WeatherManager.Start(onWeatherChanged)
	print(string.format("[Weather] Started | Cloudiness: %.2f | Moisture: %.2f | Pressure: %.2f | StormPotential: %.2f", env.Cloudiness, env.Moisture, env.Pressure, env.StormPotential))
	onWeatherChanged(currentWeather, WEATHER_DURATION[currentWeather])

	while true do
		local waitTime = math.random(ENV_CONFIG.UpdateIntervalMin, ENV_CONFIG.UpdateIntervalMax)
		task.wait(waitTime)

		updateEnvironment()

		print(string.format("[Weather] Cloudiness: %.2f | Moisture: %.2f | Pressure: %.2f | StormPotential: %.2f", env.Cloudiness, env.Moisture, env.Pressure, env.StormPotential))

		if os.clock() - weatherStartTime >= ENV_CONFIG.MinDuration then
			local validWeathers = getValidWeathers()
			print("[Weather] Valid options:", table.concat(validWeathers, ", "))

			local nextWeather = validWeathers[math.random(1, #validWeathers)]

			if nextWeather ~= currentWeather then
				local overcastDuration = WeatherConfig.Data[nextWeather] and WeatherConfig.Data[nextWeather].OvercastDuration

				if overcastDuration then
					print(string.format("[Weather] %s -> Overcast (%ds) -> %s", currentWeather, overcastDuration, nextWeather))
					onWeatherChanged("Overcast", overcastDuration)
					task.wait(overcastDuration)
				end

				print(string.format("[Weather] -> %s (%ds)", nextWeather, WEATHER_DURATION[nextWeather]))
				currentWeather = nextWeather
				weatherStartTime = os.clock()
				onWeatherChanged(currentWeather, WEATHER_DURATION[currentWeather])
			else
				print("[Weather] Staying on", currentWeather)
			end
		else
			print(string.format("[Weather] Min duration not met (%ds remaining)", ENV_CONFIG.MinDuration - (os.clock() - weatherStartTime)))
		end
	end
end

function WeatherManager.GetEnvironment()
	return env
end

function WeatherManager.PreviewTicks(tickCount)
	local snapshot = {}
	for key, value in env do
		snapshot[key] = value
	end

	local snapshotTrend = {}
	for key, value in trend do
		snapshotTrend[key] = value
	end

	for i = 1, tickCount do
		updateEnvironment()
		print(string.format("[Preview] Tick %d | Cloudiness: %.2f | Moisture: %.2f | Pressure: %.2f | StormPotential: %.2f", i, env.Cloudiness, env.Moisture, env.Pressure, env.StormPotential))
	end

	for key, value in snapshot do
		env[key] = value
	end
	for key, value in snapshotTrend do
		trend[key] = value
	end
end

return WeatherManager