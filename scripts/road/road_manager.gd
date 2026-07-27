extends Node
class_name Road_manager

@export var core: World
@export var car_movement: Car_Movement

const start_distance = 5.0

func _ready() -> void:
	core.path_follow_3d.rotation_mode = PathFollow3D.ROTATION_XYZ
	core.path_follow_3d.loop = false
	core.path_follow_3d.progress = 0.0

func _process(delta: float) -> void:
	core.path_follow_3d.progress += car_movement.speed * delta
	core.road.global_transform = core.path_follow_3d.global_transform.affine_inverse()
