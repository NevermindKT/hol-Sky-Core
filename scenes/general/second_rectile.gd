extends Control
class_name SecondaryReticle

var aim_controller: Aim_Controller
@export var follow_speed: float = 15.0 

func _process(delta: float) -> void:
	var target_pos := aim_controller.secondary_reticle_screen_pos
	global_position = global_position.lerp(target_pos, 1.0 - exp(-follow_speed * delta))
