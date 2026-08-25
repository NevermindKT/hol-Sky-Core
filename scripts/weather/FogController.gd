extends Node
class_name FogController

@export var world_environment: WorldEnvironment


func _ready():
	Events.weather_changed.connect(_on_weather_changed)
	
	if WeatherManager.weather_data && WeatherManager.weather_data.fog:
		apply_data(WeatherManager.weather_data.fog)


func _on_weather_changed():
	if WeatherManager.weather_data && WeatherManager.weather_data.fog:
		apply_data(WeatherManager.weather_data.fog)
	
	
func apply_data(data: FogData):
	var environment := world_environment.environment
	
	environment.volumetric_fog_density = data.density
