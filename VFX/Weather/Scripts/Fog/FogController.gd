extends Node
class_name FogController

@export var world_environment: WorldEnvironment


func _ready():
	WeatherManager.weather_changed.connect(_on_weather_changed)
	
	if WeatherManager.weather_state && WeatherManager.weather_state.fog:
		apply_profile(WeatherManager.weather_state.fog)


func _on_weather_changed():
	if WeatherManager.weather_state && WeatherManager.weather_state.fog:
		apply_profile(WeatherManager.weather_state.fog)
	
	
func apply_profile(profile: FogProfile):
	var environment := world_environment.environment
	
	environment.volumetric_fog_density = profile.density
