extends Node
class_name Road_manager

var world: World
var car_movement: Car_Movement

var turn_velocity := 0.0
var smoothed_turn_velocity := 0.0

@export var turn_smoothing := 8.0
@export var sample_distance := 5.0

func initialize(start_distance: float):
	if world == null:
		push_warning("World не призначений. Ініціалізацію неможливо виконати.")
		return
	if car_movement == null:
		push_warning("Car не призначений. Ініціалізацію неможливо виконати.")
		return

	world.path_follow_3d.rotation_mode = PathFollow3D.ROTATION_XYZ
	world.path_follow_3d.progress = start_distance
	world.path_follow_3d.loop = false

	world.world.global_transform = world.path_follow_3d.global_transform.affine_inverse()


func _process(delta: float):
	if world == null:
		return

	world.path_follow_3d.progress += car_movement.speed * delta

	update_turn_velocity(delta)

	world.world.global_transform = \
		world.path_follow_3d.global_transform.affine_inverse()


func update_turn_velocity(delta: float):
	var curve := world.world_path.curve
	var progress := world.path_follow_3d.progress


	var pos_a := curve.sample_baked(progress)
	var pos_b := curve.sample_baked(
		progress + sample_distance
	)
	var pos_c := curve.sample_baked(
		progress + sample_distance * 2.0
	)

	var dir_a := (pos_b - pos_a).normalized()
	var dir_b := (pos_c - pos_b).normalized()

	var angle := atan2(
		dir_a.x * dir_b.z - dir_a.z * dir_b.x,
		dir_a.x * dir_b.x + dir_a.z * dir_b.z
	)

	turn_velocity = angle * car_movement.speed

	smoothed_turn_velocity = lerpf(
		smoothed_turn_velocity,
		turn_velocity,
		1.0 - exp(-turn_smoothing * delta)
	)
