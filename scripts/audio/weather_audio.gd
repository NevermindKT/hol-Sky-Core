extends Node
class_name WeatherAudio

@export var car: Car_Movement

@export_group("Rain")
@export var rain_light: AmbientLayer
@export var rain_heavy: AmbientLayer
@export var rain_on_car: AmbientLayer
@export var rain_on_window: AmbientLayer
@export var rain_hear_distance := 120.0
@export var under_rain_start := 6.0
@export var under_rain_end := 15.0
@export_range(0.0, 1.0) var light_rain_on_car := 0.5


func _process(_delta: float) -> void:
	if car == null:
		return
	_update_rain()


func _update_rain() -> void:
	var light := 0.0
	var heavy := 0.0
	var under := 0.0

	for zone: WeatherZone in get_tree().get_nodes_in_group("weather_zones"):
		var rain: RainData = zone.get_rain()
		if rain == null or not rain.enabled:
			continue

		var distance: float = zone.distance_to(car.global_position)
		var near := 1.0 - smoothstep(under_rain_start, rain_hear_distance, distance)
		var inside := 1.0 - smoothstep(under_rain_start, under_rain_end, distance)

		if rain.heavy:
			heavy = maxf(heavy, near)
			under = maxf(under, inside)
		else:
			light = maxf(light, near)
			under = maxf(under, inside * light_rain_on_car)

	rain_light.target = light
	rain_heavy.target = heavy
	rain_on_car.target = under
	rain_on_window.target = under
