local ServerScriptService = game:GetService("ServerScriptService")

local WeatherManager = require(ServerScriptService.Weather.WeatherManager)
local WeatherService = require(ServerScriptService.Weather.WeatherService)

WeatherManager.Start(function(weatherName, duration)
	print(string.format("[Weather] Applying %s for %ds", weatherName, duration))
	WeatherService.Apply(weatherName, duration)
end)