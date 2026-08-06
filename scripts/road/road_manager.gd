extends Node
class_name Road_manager

var world: World
var car_movement: Car_Movement

var angular_velocity := Vector3.ZERO
var last_rotation := Quaternion.IDENTITY

var distance_traveled := 0


func initialize():
	world.path_follow_3d.rotation_mode = PathFollow3D.ROTATION_XYZ
	world.path_follow_3d.loop = false
	world.path_follow_3d.progress = 0.0
	
	print(world.path_follow_3d.progress)
	print(world.path_follow_3d.global_position)
	
	last_rotation = world.path_follow_3d.global_basis.get_rotation_quaternion()
	world.world.global_transform = world.path_follow_3d.global_transform.affine_inverse()


func _process(delta):
	world.path_follow_3d.progress += car_movement.speed * delta
	
	var current = world.path_follow_3d.global_basis.get_rotation_quaternion()

	var delta_rot = last_rotation.inverse() * current
	var axis = delta_rot.get_axis()
	var angle = delta_rot.get_angle()

	angular_velocity = axis * angle / delta

	last_rotation = current

	world.world.global_transform = world.path_follow_3d.global_transform.affine_inverse()
