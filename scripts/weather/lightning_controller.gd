extends Node

@export var directional_light: DirectionalLight3D
@onready var lightning: LightningBolt = $LightningBolt
var spawn_area: LightningSpawnArea

var timer: Timer

var default_light_energy: float

var flashing := false

func _ready():
	spawn_area = get_tree().get_first_node_in_group("lightning_spawn")

	if spawn_area == null:
		push_error("LightningSpawnArea not found.")
	
	default_light_energy = directional_light.light_energy
	
	timer = Timer.new()
	add_child(timer)

	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)

	Events.weather_changed.connect(_on_weather_changed)

	_on_weather_changed()


func _on_weather_changed():
	timer.stop()

	var weather_data: WeatherData = WeatherManager.weather_data
	if weather_data == null:
		return

	if weather_data.rain == null:
		return

	if weather_data.rain.lightning_enabled:
		_schedule_next_flash()


func _schedule_next_flash():
	var weather_data: WeatherData = WeatherManager.weather_data
	if weather_data == null:
		return

	var rain := weather_data.rain
	if rain == null:
		return

	var delay := randf_range(
		rain.lightning_min_interval,
		rain.lightning_max_interval
	)

	timer.start(delay)


func _on_timer_timeout():
	await flash()
	_schedule_next_flash()


func _flash_step(intensity: float, duration: float) -> void:
	lightning.show_bolt()
	directional_light.light_energy = default_light_energy + intensity
	await get_tree().create_timer(duration).timeout
	lightning.hide_bolt()
	
func _pause(duration: float) -> void:
	directional_light.light_energy = default_light_energy
	await get_tree().create_timer(duration).timeout

func flash() -> void:
	if flashing:
		return

	flashing = true

	var weather_data: WeatherData = WeatherManager.weather_data
	if weather_data == null or weather_data.rain == null:
		flashing = false
		return

	var rain := weather_data.rain
	lightning.strike(spawn_area.get_random_position())
	var flashes := randi_range(2, 4)

	for i in flashes:
		var intensity := rain.lightning_intensity * randf_range(0.7, 1.2)
		var duration := randf_range(0.02, 0.05)

		await _flash_step(intensity, duration)
		
		if i < flashes - 1:
			await _pause(randf_range(0.015, 0.04))

	directional_light.light_energy = default_light_energy

	flashing = false
