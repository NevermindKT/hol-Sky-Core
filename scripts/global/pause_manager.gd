extends Node
class_name Pause_Manager

var is_paused := false
var is_game_over := false

signal pause_state_changed

func _ready() -> void:
	InputController.pause_toggle.connect(toggle_pause)
	GameFlow.restart_requested.connect(_on_restart)

func toggle_pause():
	if is_game_over:
		return
	set_paused(!is_paused)


func set_paused(value: bool):
	is_paused = value
	get_tree().paused = is_paused
	pause_state_changed.emit()


func set_game_over() -> void:
	is_game_over = true
	set_paused(true)

func _on_restart():
	is_paused = false
	is_game_over = false
