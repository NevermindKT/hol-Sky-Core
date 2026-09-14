extends Camera3D
class_name Player_Camera

@export var car: Car_Movement
@export var cam_latency := 2.0
@export var fov_smoothing := 8.0

var _base_fov: float

func _ready() -> void:
	_base_fov = fov

func _physics_process(delta):
	var pos = global_position
	pos.x = lerp(pos.x, car.cam_pivot.global_position.x, cam_latency * delta)
	global_position = pos

	var target_fov := UpgradeManager.get_modified(&"camera_fov", _base_fov)
	var t := 1.0 - exp(-fov_smoothing * delta)
	fov = lerpf(fov, target_fov, t)
