extends Node

@export var weapon_pivot: Node3D
@onready var car: Car_Movement = $".."

func _process(_delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	
	var origin = car.player_cam.project_ray_origin(mouse_pos)
	var direction = car.player_cam.project_ray_normal(mouse_pos)

	var target = origin + direction * 1000.0
	
	if target:
		weapon_pivot.look_at(target)
