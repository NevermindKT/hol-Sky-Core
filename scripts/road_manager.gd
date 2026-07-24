extends Node
class_name Road_manager

@onready var car_movement: Car_Movement = $"../../Car"

@onready var world: Node3D = $"../World"
@onready var path_follow_3d: PathFollow3D = $"../WorldPath/PathFollow3D"


func _ready() -> void:
	path_follow_3d.rotation_mode = PathFollow3D.ROTATION_XYZ
	path_follow_3d.loop = false
	path_follow_3d.progress = 0.0

func _process(delta: float) -> void:
	path_follow_3d.progress += car_movement.speed * delta
	world.global_transform = path_follow_3d.global_transform.affine_inverse()
