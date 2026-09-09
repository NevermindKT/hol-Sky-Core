extends Node
class_name FogController

@export var world_environment: WorldEnvironment
@export var transition_speed := 0.5

var _target_density := 0.0


func _ready():
	Events.weather_changed.connect(_on_weather_changed)

	if WeatherManager.weather_data && WeatherManager.weather_data.fog:
		var data := WeatherManager.weather_data.fog
		_target_density = data.density
		world_environment.environment.volumetric_fog_density = data.density


func _process(delta: float) -> void:
	if world_environment == null:
		return

	var environment := world_environment.environment
	var t := 1.0 - exp(-transition_speed * delta)
	environment.volumetric_fog_density = lerpf(environment.volumetric_fog_density, _target_density, t)


func _on_weather_changed():
	if WeatherManager.weather_data && WeatherManager.weather_data.fog:
		apply_data(WeatherManager.weather_data.fog)


func apply_data(data: FogData):
	_target_density = data.density
