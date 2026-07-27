extends Node
class_name Road_manager

@export var world: World
@export var car_movement: Car_Movement

const start_distance = 5.0

func _ready() -> void:
	world.path_follow_3d.rotation_mode = PathFollow3D.ROTATION_XYZ
	world.path_follow_3d.loop = false
	world.path_follow_3d.progress = 0.0

func _process(delta: float) -> void:
	world.path_follow_3d.progress += car_movement.speed * delta
	world.world.global_transform = world.path_follow_3d.global_transform.affine_inverse()
