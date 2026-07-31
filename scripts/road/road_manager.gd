extends Node
class_name Road_manager

@export var world: World
var angular_velocity := Vector3.ZERO
@export var car_movement: Car_Movement
var last_rotation := Quaternion.IDENTITY

const start_distance = 5.0

func _ready() -> void:
	world.path_follow_3d.rotation_mode = PathFollow3D.ROTATION_XYZ
	world.path_follow_3d.loop = false
	world.path_follow_3d.progress = 0.0


func _process(delta):
	world.path_follow_3d.progress += car_movement.speed * delta

	var current = world.path_follow_3d.global_basis.get_rotation_quaternion()

	var delta_rot = last_rotation.inverse() * current
	var axis = delta_rot.get_axis()
	var angle = delta_rot.get_angle()

	angular_velocity = axis * angle / delta

	last_rotation = current

	world.world.global_transform = world.path_follow_3d.global_transform.affine_inverse()
