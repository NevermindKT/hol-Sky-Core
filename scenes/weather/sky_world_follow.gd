extends Node
class_name Sky_world_follow

@export var world_root: World
@export var world_environment: WorldEnvironment

@export var yaw_multiplier := 1.0

var _sky_material: ShaderMaterial

func _ready() -> void:
	var env := world_environment.environment
	if env != null and env.sky != null:
		_sky_material = env.sky.sky_material as ShaderMaterial


func _process(_delta: float) -> void:
	if _sky_material == null or world_root == null:
		return

	_sky_material.set_shader_parameter("cloud_yaw", world_root.world.global_rotation.y * yaw_multiplier)
