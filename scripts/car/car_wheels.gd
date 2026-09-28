extends Node3D
class_name Car_Wheels


@export_category("Wheels")
@export var front_left: Node3D
@export var front_right: Node3D
@export var rear_left: Node3D
@export var rear_right: Node3D

@export var front_left_mesh: Node3D
@export var front_right_mesh: Node3D
@export var rear_left_mesh: Node3D
@export var rear_right_mesh: Node3D


@export_category("Rolling")
@export var wheel_radius := 0.35
@export var roll_multiplier := 1.0


@export_category("Steering")
@export var max_steer_angle := 28.0
@export var steer_response := 12.0


@export_category("Spare Tire")
@export var restore_time := 0.35


var missing_wheel: Node3D

var _roll_angle := 0.0
var _current_steer := 0.0
var _meshes: Dictionary = {}
var _mesh_scales: Dictionary = {}


func _ready() -> void:
	_meshes = {
		front_left: front_left_mesh,
		front_right: front_right_mesh,
		rear_left: rear_left_mesh,
		rear_right: rear_right_mesh,
	}
	_meshes.erase(null)

	for mesh in _meshes.values():
		if mesh:
			_mesh_scales[mesh] = mesh.scale


func process_wheels(delta: float, speed: float, steering_input: float) -> void:
	_process_rolling(delta, speed)
	_process_steering(delta, steering_input)


func _process_rolling(delta: float, speed: float) -> void:
	if is_zero_approx(wheel_radius):
		return

	_roll_angle += (speed / wheel_radius) * roll_multiplier * delta
	_roll_angle = wrapf(_roll_angle, 0.0, TAU)

	_set_roll(front_left_mesh)
	_set_roll(front_right_mesh)
	_set_roll(rear_left_mesh)
	_set_roll(rear_right_mesh)


func _process_steering(delta: float, steering_input: float) -> void:
	var target := clampf(steering_input, -1.0, 1.0) * deg_to_rad(max_steer_angle)

	_current_steer = lerp(
		_current_steer,
		target,
		1.0 - exp(-steer_response * delta)
	)

	_set_steer(front_left)
	_set_steer(front_right)


func _set_roll(mesh: Node3D) -> void:
	if mesh == null:
		return
	mesh.rotation.x = _roll_angle


func _set_steer(pivot: Node3D) -> void:
	if pivot == null:
		return
	pivot.rotation.y = _current_steer


func get_wheel_mesh(pivot: Node3D) -> Node3D:
	return _meshes.get(pivot)


func detach_random_wheel() -> Node3D:
	if missing_wheel != null or _meshes.is_empty():
		return null

	missing_wheel = _meshes.keys().pick_random()

	var mesh := get_wheel_mesh(missing_wheel)
	if mesh:
		mesh.visible = false

	return missing_wheel


func restore_missing_wheel() -> void:
	if missing_wheel == null:
		return

	var mesh := get_wheel_mesh(missing_wheel)
	missing_wheel = null

	if mesh == null:
		return

	var target_scale: Vector3 = _mesh_scales.get(mesh, mesh.scale)
	mesh.scale = target_scale * 0.01
	mesh.visible = true

	var tween := create_tween()
	tween.tween_property(mesh, "scale", target_scale, restore_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
