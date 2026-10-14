extends Node
class_name WeatherAudio

@export var car: Car_Movement

@export_group("Rain")
@export var rain_light: WeatherAudioLayer
@export var rain_heavy: WeatherAudioLayer
@export var rain_on_car: WeatherAudioLayer
@export var rain_on_window: WeatherAudioLayer
@export var rain_hear_distance := 120.0
@export var under_rain_start := 6.0
@export var under_rain_end := 15.0
@export_range(0.0, 1.0) var light_rain_on_car := 0.5

@export_group("Thunder")
@export var thunder_close: AudioStreamPlayer3D
@export var thunder_distant: AudioStreamPlayer
@export var thunder_close_max_db := 0.0
@export var thunder_distant_max_db := -6.0
@export var distant_min_interval := 6.0
@export var distant_max_interval := 18.0
@export var speed_of_sound := 100.0

var _storm_level := 0.0
var _distant_timer := 0.0


func _ready() -> void:
	Events.lightning_struck.connect(_on_lightning_struck)


func _process(delta: float) -> void:
	if car == null:
		return
	_update_rain()
	_update_distant_thunder(delta)


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
	_storm_level = heavy
	
func _on_lightning_struck(strike_position: Vector3) -> void:
	thunder_close.global_position = strike_position
	thunder_close.volume_db = thunder_close_max_db

	var distance := strike_position.distance_to(car.global_position)
	await get_tree().create_timer(distance / speed_of_sound).timeout
	thunder_close.play()


func _update_distant_thunder(delta: float) -> void:
	if _storm_level <= 0.0:
		_distant_timer = randf_range(0.0, distant_min_interval)
		return

	_distant_timer -= delta
	if _distant_timer > 0.0:
		return

	_distant_timer = randf_range(distant_min_interval, distant_max_interval)
	thunder_distant.volume_db = thunder_distant_max_db + linear_to_db(_storm_level)
	thunder_distant.play()
