extends Control
class_name Cross_Hair


@onready var reload_bar: ProgressBar = $ReloadBar

func _process(_delta: float) -> void:
	global_position = get_viewport().get_mouse_position() - size * 0.5
