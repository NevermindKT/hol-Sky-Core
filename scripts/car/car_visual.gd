extends Node3D
class_name Car_Visual_Effects


@export var y_tilt := 16.0
@export var z_tilt := 16.0

@export var road_y_tilt := 6.0
@export var road_z_tilt := 8.0

@export var max_lateral_speed := 10.0
@export var max_turn_velocity := 5.0

@export var delta_mul := 10.0

@onready var visual: Car_Visual_Effects = $"."

func process_visual_tilt(
	delta: float,
	lateral_speed: float,
	turn_velocity: float
):
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

	visual.rotation.y = lerp_angle(
		visual.rotation.y,
		target_y,
		delta * delta_mul
	)

	visual.rotation.z = lerp_angle(
		visual.rotation.z,
		target_z,
		delta * delta_mul
	)
