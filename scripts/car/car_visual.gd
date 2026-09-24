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


var tilt_velocity_y := 0.0
var tilt_velocity_z := 0.0


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


func apply_dodge_impulse(direction: float) -> void:
	tilt_velocity_y -= direction * dodge_yaw_impulse
	tilt_velocity_z += direction * dodge_roll_impulse
