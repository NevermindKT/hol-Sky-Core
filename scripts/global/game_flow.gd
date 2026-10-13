extends Node
class_name RestartManager

signal restart_requested

func restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0

	restart_requested.emit()
	get_tree().reload_current_scene()
