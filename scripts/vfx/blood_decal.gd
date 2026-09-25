extends Decal
class_name Blood_decal

@export var texture_variants: Array[Texture2D] = []
@export var normal_variants: Array[Texture2D] = []
@export var orm_variants: Array[Texture2D] = []

@export var surface_margin: float = 0.05

@export var scale_range: Vector2 = Vector2(0.7, 1.3)

@export var color_boost: Color = Color(1.0, 1.0, 1.0, 1.0)

@export var emission_energy_start: float = 6.0
@export var emission_energy_floor: float = 0.6
@export var emission_fade_duration: float = 3.0

@export_group("Rain wash")
@export var wash_duration_light: float = 20.0
@export var wash_duration_heavy: float = 8.0
@export var wash_curve_power: float = 1.5

var _wash := 1.0
var _wash_speed := 0.0
var _emission_base := 0.0

func _ready() -> void:
	if texture_variants.is_empty():
		push_warning("Blood_decal: texture_variants порожній — призначте PNG-варіанти в Inspector.")
		return

	var index := randi() % texture_variants.size()
	texture_albedo = texture_variants[index]

	if index < normal_variants.size():
		texture_normal = normal_variants[index]
	if index < orm_variants.size():
		texture_orm = orm_variants[index]

	texture_emission = texture_variants[index]
	_emission_base = emission_energy_start

	apply_random_scale(scale_range)
	_apply_wash()

	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_set_emission_base, emission_energy_start, emission_energy_floor, emission_fade_duration)

	Events.weather_changed.connect(_on_weather_changed)
	_on_weather_changed()


func _process(delta: float) -> void:
	if _wash_speed <= 0.0:
		return

	_wash = maxf(_wash - _wash_speed * delta, 0.0)
	_apply_wash()

	if _wash <= 0.0:
		queue_free()


func _on_weather_changed() -> void:
	var rain := WeatherManager.weather_data.rain if WeatherManager.weather_data != null else null

	if rain == null or not rain.enabled:
		_wash_speed = 0.0
	else:
		var duration := wash_duration_heavy if rain.heavy else wash_duration_light
		_wash_speed = 1.0 / maxf(duration, 0.01)

	set_process(_wash_speed > 0.0)


func _set_emission_base(value: float) -> void:
	_emission_base = value
	_apply_wash()


func _apply_wash() -> void:
	var visibility := pow(_wash, wash_curve_power)

	var color := color_boost
	color.a *= visibility
	modulate = color

	emission_energy = _emission_base * visibility


func apply_random_scale(_range: Vector2) -> void:
	scale = Vector3.ONE * randf_range(_range.x, _range.y)


func place(surface_position: Vector3, surface_normal: Vector3) -> void:
	var up := surface_normal.normalized()
	var reference := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD

	var new_basis := Basis()
	new_basis.y = up
	new_basis.x = reference.cross(up).normalized()
	new_basis.z = new_basis.x.cross(up).normalized()

	global_basis = new_basis.rotated(up, randf_range(0.0, TAU))
	global_position = surface_position + up * surface_margin
