extends Node
class_name Weather_generator


var road_generator: Road_generator
var road_manager: Road_manager

@export var weather_zone_scene: PackedScene

@export var available_rain: Array[RainData] = []
@export var available_fog: Array[FogData] = []
@export var min_segments_per_weather := 5
@export var max_segments_per_weather := 20

var current_weather := WeatherData.new()
var segments_since_change := 0
var segments_until_change := 0


func _ready() -> void:
	if road_generator == null:
		push_warning("Weather_generator: road_generator не призначений.")
		return
		
	Events.segment_spawned.connect(_on_segment_spawned)
	_pick_new_weather()
	WeatherManager.set_weather(current_weather)


func _on_segment_spawned(segment: Road_segment) -> void:
	segments_since_change += 1

	if segments_since_change >= segments_until_change:
		_pick_new_weather()

	if weather_zone_scene == null:
		return

	var zone := weather_zone_scene.instantiate() as WeatherZone
	zone.road_manager = road_manager
	segment.add_child(zone)
	zone.apply_weather(current_weather)
	zone.apply_road(segment)


func _pick_new_weather() -> void:
	segments_since_change = 0
	segments_until_change = randi_range(min_segments_per_weather, max_segments_per_weather)

	current_weather.rain = _pick_smoothed(available_rain, current_weather.rain)
	current_weather.fog = _pick_smoothed(available_fog, current_weather.fog)


func _pick_smoothed(available: Array, current: Variant) -> Variant:
	if available.is_empty():
		return null

	if current == null:
		return available[0]

	var rand_int := randi() % 3 - 1
	var current_index := available.find(current)
	var next_index := clampi(current_index + rand_int, 0, available.size() - 1)
	return available[next_index]
