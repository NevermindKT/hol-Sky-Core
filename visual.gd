extends Node3D
class_name Car_Visual_Effects

@export var y_tilt := 7.0
@export var z_tilt := 6.0
@export var delta_mul := 10.0

@onready var visual: Node3D = $"."

func process_visual_tilt(delta: float, input: float):
	visual.rotation.y = lerp_angle(
		visual.rotation.y,
		-input * deg_to_rad(y_tilt),
		delta * delta_mul
	)
	visual.rotation.z = lerp_angle(
		visual.rotation.z,
		-input * deg_to_rad(z_tilt),
		delta * delta_mul
	)
