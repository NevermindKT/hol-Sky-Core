extends Node3D
class_name BloodCarHit


@export var splash: GPUParticles3D
@export_range(10.0, 180.0) var spread: float = 60.0
@export var lifetime: float = 5.0

@export_group("Speed influence")
@export var reference_speed: float = 20.0
@export var min_intensity_scale: float = 0.4
@export var max_intensity_scale: float = 2.0

var _base_amount: int
var _base_velocity_min: float
var _base_velocity_max: float

func _ready() -> void:
	splash.one_shot = true
	splash.emitting = false

	var mat := splash.process_material as ParticleProcessMaterial
	if mat:
		mat = mat.duplicate()
		mat.direction = Vector3.FORWARD
		mat.spread = spread
		splash.process_material = mat

		_base_velocity_min = mat.initial_velocity_min
		_base_velocity_max = mat.initial_velocity_max

	_base_amount = splash.amount

func play(hit_position: Vector3, hit_direction: Vector3, car_speed: float = 0.0) -> void:
	global_position = hit_position
	_orient_to(hit_direction)

	var speed_scale := 1.0
	if reference_speed > 0.0:
		speed_scale = clampf(car_speed / reference_speed, min_intensity_scale, max_intensity_scale)

	var mat := splash.process_material as ParticleProcessMaterial
	if mat:
		mat.initial_velocity_min = _base_velocity_min * speed_scale
		mat.initial_velocity_max = _base_velocity_max * speed_scale

	splash.amount = maxi(1, int(_base_amount * speed_scale))
	splash.restart()


	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _orient_to(hit_direction: Vector3) -> void:
	var direction := hit_direction
	direction.y = 0.0

	if direction.length_squared() <= 0.0001:
		return

	look_at(global_position + direction, Vector3.UP)
