extends Node
class_name Pause_Manager

var is_paused := false

signal pause_state_changed

func _ready() -> void:
	InputController.pause_toggle.connect(toggle_pause)

func toggle_pause():
	set_paused(!is_paused)


func set_paused(value: bool):
	is_paused = value
	get_tree().paused = is_paused
	pause_state_changed.emit()
