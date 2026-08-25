extends Node
class_name LightningController

@export var directional_light: DirectionalLight3D

## Потрібен, щоб рахувати позицію удару в тих самих координатах дорожньої
## кривої, що й ground_generator/road_generator, а не у статичних
## координатах Environment — інакше блискавка не "їде" разом зі світом
## на поворотах і виглядає приклеєною до фону (як DistanceFog).
@export var world: World

@export_group("Strike Area")
## Наскільки далеко попереду поточної позиції машини на кривій (world.path_follow_3d.progress)
## може вдарити блискавка.
@export var strike_ahead_min := 55.0
@export var strike_ahead_max := 75.0
## Розкид ліворуч/праворуч від центру дороги.
@export var strike_lateral_range := 35.0

@onready var lightning: LightningBolt = $LightningBolt

var timer: Timer

var default_light_energy: float

var flashing := false

func _ready():
	if world == null:
		push_warning("LightningController: world не призначений — блискавка не зможе порахувати позицію удару.")

	default_light_energy = directional_light.light_energy
	
	timer = Timer.new()
	add_child(timer)

	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)

	Events.weather_changed.connect(_on_weather_changed)

	_on_weather_changed()


## Events.weather_changed летить набагато частіше, ніж реально міняється
## погода — WeatherZone анонсує себе на кожному новому сегменті дороги
## (кожні ~20 одиниць), навіть якщо це та сама гроза, що й секунду тому.
## Тому тут НЕ можна безумовно перезапускати таймер щоразу — інакше він
## ніколи не встигає дійти до 0 під час безперервної їзди. Скидаємо його
## тільки коли блискавка справді вимкнена (гроза закінчилась), і плануємо
## нову тільки якщо таймер ще не йде і зараз не триває спалах.
func _on_weather_changed():
	var weather_data: WeatherData = WeatherManager.weather_data
	var rain := weather_data.rain if weather_data else null

	if rain == null or not rain.lightning_enabled:
		timer.stop()
		return

	if timer.is_stopped() and not flashing:
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
	lightning.strike(_random_strike_transform())
	var flashes := randi_range(2, 4)

	for i in flashes:
		var intensity := rain.lightning_intensity * randf_range(0.7, 1.2)
		var duration := randf_range(0.02, 0.05)

		await _flash_step(intensity, duration)
		
		if i < flashes - 1:
			await _pause(randf_range(0.015, 0.04))

	directional_light.light_energy = default_light_energy

	flashing = false


## Рахує позицію удару в локальних координатах дорожньої кривої (так само,
## як ground_generator/road_generator будують геометрію), а потім переводить
## через ПОТОЧНИЙ world.world.global_transform у видиму систему координат.
## Саме тому позиція виходить коректною і на поворотах: той самий
## global_transform, що обертає RoadContainer/GroundContainer під час
## повороту, тут застосовується вручну до однієї точки.
func _random_strike_transform() -> Transform3D:
	if world == null or world.world_path == null or world.world_path.curve == null:
		return Transform3D(Basis.IDENTITY, Vector3.ZERO)

	var curve := world.world_path.curve
	var ahead := randf_range(strike_ahead_min, strike_ahead_max)
	var progress := clampf(
		world.path_follow_3d.progress + ahead,
		0.0,
		curve.get_baked_length()
	)

	var sample := curve.sample_baked_with_rotation(progress)
	var lateral := randf_range(-strike_lateral_range, strike_lateral_range)
	var local_point := sample.origin + sample.basis.x * lateral

	return world.world.global_transform * Transform3D(Basis.IDENTITY, local_point)
