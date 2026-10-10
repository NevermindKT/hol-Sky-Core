extends Node
class_name Pause_Manager

var is_paused := false

signal pause_state_changed

func _ready() -> void:
	InputController.pause_toggle.connect(toggle_pause)
	GameFlow.restart_requested.connect(_on_restart)

func toggle_pause():
	set_paused(!is_paused)


func set_paused(value: bool):
	is_paused = value
	get_tree().paused = is_paused
	pause_state_changed.emit()

func _on_restart():
	is_paused = false
