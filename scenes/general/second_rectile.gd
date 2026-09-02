extends Control
class_name SecondaryReticle

var aim_controller: Aim_Controller
@export var follow_speed: float = 15.0

@export var min_scale: float = 1.0
@export var max_scale: float = 2.5


func _ready() -> void:
	Events.spread_changed.connect(_on_spread_changed)


func _on_spread_changed(ratio: float) -> void:
	var s = lerp(min_scale, max_scale, ratio)
	scale = Vector2(s, s) 


func _process(delta: float) -> void:
	var target_pos := aim_controller.secondary_reticle_screen_pos
	global_position = global_position.lerp(target_pos, 1.0 - exp(-follow_speed * delta))
