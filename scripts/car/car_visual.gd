extends Node3D
class_name Car_Visual_Effects


@export var y_tilt := 16.0
@export var z_tilt := 16.0
@export var delta_mul := 10.0
@export var max_lateral_speed := 10.0
@export var road_manager: Road_manager

@onready var visual: Car_Visual_Effects = $"."


func process_visual_tilt(delta: float, lateral_speed: float):
	var tilt_strength := clampf(
		lateral_speed / max_lateral_speed,
		-1.0,
		1.0
	)

	visual.rotation.y = lerp_angle(
		visual.rotation.y,
		-tilt_strength * deg_to_rad(y_tilt),
		delta * delta_mul
	)

	visual.rotation.z = lerp_angle(
		visual.rotation.z,
		tilt_strength * deg_to_rad(z_tilt),
		delta * delta_mul
	)
	
	#var turn_strength = clamp(
		#road_manager.angular_velocity.y / max_lateral_speed,
		#-1.0,
		#1.0
	#)
	#
	#rotation.z = lerp_angle(
		#-rotation.z,
		#turn_strength * deg_to_rad(8),
		#delta * delta_mul
	#)
	#
	#rotation.y = lerp_angle(
		#-rotation.y,
		#turn_strength * deg_to_rad(8),
		#delta * delta_mul
	#)
