extends Node3D
class_name Car_Visual_Effects


@export var y_tilt := 16.0
@export var z_tilt := 16.0

@export var road_y_tilt := 6.0
@export var road_z_tilt := 8.0

@export var max_lateral_speed := 10.0
@export var max_turn_velocity := 5.0


@export_category("Spring")
@export var tilt_spring := 120.0
@export var tilt_damping := 14.0
@export var max_tilt_velocity := 25.0


@export_category("Dodge Impulse")
@export var dodge_yaw_impulse := 9.0
@export var dodge_roll_impulse := 7.0


@export_category("Missing Wheel")
@export var missing_wheel_roll_deg := 4.0
@export var missing_wheel_pitch_deg := 2.0
@export var missing_wheel_drop_impulse := 3.0
@export var missing_wheel_tilt_speed := 2.5
@export var missing_wheel_wobble_deg := 0.6
@export var missing_wheel_wobble_frequency := 7.0


var tilt_velocity_y := 0.0
var tilt_velocity_z := 0.0

var _missing_wheel_tilt := Vector2.ZERO
var _missing_wheel_amount := 0.0
var _missing_wheel_target := 0.0
var _wobble_time := 0.0


func process_visual_tilt(delta: float, lateral_speed: float, turn_velocity: float):
	var tilt_strength := clampf(
		lateral_speed / max_lateral_speed,
		-1.0,
		1.0
	)

	var turn_strength := clampf(
		-turn_velocity / max_turn_velocity,
		-1.0,
		1.0
	)

	var target_y := (
		-tilt_strength * deg_to_rad(y_tilt)
		+ turn_strength * deg_to_rad(road_y_tilt)
	)

	var target_z := (
		tilt_strength * deg_to_rad(z_tilt)
		+ turn_strength * deg_to_rad(road_z_tilt)
	)

	var missing_wheel_offset := _process_missing_wheel(delta)
	target_z += missing_wheel_offset.y
	rotation.x = missing_wheel_offset.x

	rotation.y = _spring_angle(rotation.y, target_y, "tilt_velocity_y", delta)
	rotation.z = _spring_angle(rotation.z, target_z, "tilt_velocity_z", delta)


func _spring_angle(current: float, target: float, velocity_property: StringName, delta: float) -> float:
	var velocity: float = get(velocity_property)

	var error := angle_difference(current, target)

	velocity += error * tilt_spring * delta
	velocity *= clampf(1.0 - tilt_damping * delta, 0.0, 1.0)
	velocity = clampf(velocity, -max_tilt_velocity, max_tilt_velocity)

	set(velocity_property, velocity)

	return current + velocity * delta


func _process_missing_wheel(delta: float) -> Vector2:
	_missing_wheel_amount = move_toward(_missing_wheel_amount, _missing_wheel_target, missing_wheel_tilt_speed * delta)

	if is_zero_approx(_missing_wheel_amount):
		_wobble_time = 0.0
		return Vector2.ZERO

	_wobble_time += delta
	var wobble := (
		sin(_wobble_time * missing_wheel_wobble_frequency * TAU)
		+ 0.5 * sin(_wobble_time * missing_wheel_wobble_frequency * 2.3 * TAU)
	) * deg_to_rad(missing_wheel_wobble_deg)

	var tilt := _missing_wheel_tilt * _missing_wheel_amount
	var wobble_direction := _missing_wheel_tilt.normalized() if _missing_wheel_tilt != Vector2.ZERO else Vector2.ZERO
	return tilt + wobble_direction * wobble * _missing_wheel_amount


func set_missing_wheel(wheel_position: Vector3) -> void:
	var roll_side := -signf(wheel_position.x)

	_missing_wheel_tilt = Vector2(
		signf(wheel_position.z) * deg_to_rad(missing_wheel_pitch_deg),
		roll_side * deg_to_rad(missing_wheel_roll_deg)
	)
	_missing_wheel_target = 1.0

	tilt_velocity_z += roll_side * missing_wheel_drop_impulse


func clear_missing_wheel() -> void:
	_missing_wheel_target = 0.0


func apply_dodge_impulse(direction: float) -> void:
	tilt_velocity_y -= direction * dodge_yaw_impulse
	tilt_velocity_z += direction * dodge_roll_impulse
