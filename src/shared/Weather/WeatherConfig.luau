local WeatherConfig = {}

WeatherConfig.Types = {"Sunny", "Cloudy", "Rain", "Storm",}
WeatherConfig.CooldownDuration = 20

WeatherConfig.Data = {
	Sunny = {
		Message = "The skies have cleared.",
		Weight = 3,
		MinDuration = 16,
		MaxDuration = 20,
		Lighting = {
			Ambient = Color3.fromRGB(80, 80, 80),
			OutdoorAmbient = Color3.fromRGB(150, 150, 150),
			Brightness = 2,
			FogColor = Color3.fromRGB(192, 192, 192),
			FogStart = 500,
			FogEnd = 100000,
			AtmosphereHaze = 0,
			AtmosphereDensity = 0.3,
		},
		CloudsCover = 0.3,
		Effects = {},
		Sounds = {},
	},
	Cloudy = {
		Message = "Clouds gather overhead.",
		Weight = 3,
		MinDuration = 15,
		MaxDuration = 25,
		Lighting = {
			Ambient = Color3.fromRGB(70, 70, 75),
			OutdoorAmbient = Color3.fromRGB(120, 120, 130),
			Brightness = 1.5,
			FogColor = Color3.fromRGB(150, 150, 160),
			FogStart = 300,
			FogEnd = 8000,
			AtmosphereHaze = 0,
			AtmosphereDensity = 0.35,
		},
		CloudsCover = 0.7,
		Effects = {},
		Sounds = {},
	},
	Rain = {
		Message = "Rain begins to fall.",
		Weight = 30,
		MinDuration = 17,
		MaxDuration = 25,
		OvercastDuration = 40,
		Lighting = {
			Ambient = Color3.fromRGB(55, 55, 65),
			OutdoorAmbient = Color3.fromRGB(90, 90, 100),
			Brightness = 0.4,
			FogColor = Color3.fromRGB(100, 100, 110),
			FogStart = 100,
			FogEnd = 2500,
			AtmosphereHaze = 0,
			AtmosphereDensity = 0.5,
		},
		CloudsCover = 0.8,
		Effects = {},
		Sounds = {"RainAmbience"},
	},
	Storm = {
		Message = "A thunderstorm rolls in.",
		Weight = 10,
		MinDuration = 16,
		MaxDuration = 20,
		OvercastDuration = 60,
		Lighting = {
			Ambient = Color3.fromRGB(35, 35, 45),
			OutdoorAmbient = Color3.fromRGB(60, 60, 70),
			Brightness = 0,
			FogColor = Color3.fromRGB(70, 70, 80),
			FogStart = 50,
			FogEnd = 900,
			AtmosphereHaze = 0,
			AtmosphereDensity = 0.55,
		},
		CloudsCover = 0.9,
		Effects = {"Lightning"},
		Sounds = {"RainAmbience", "Thunder"},
	},
	
}

return WeatherConfig