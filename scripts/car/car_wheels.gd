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


var _roll_angle := 0.0
var _current_steer := 0.0


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
