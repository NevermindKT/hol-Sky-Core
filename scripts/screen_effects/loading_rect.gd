extends ColorRect
class_name LoadingScreen

func _ready() -> void:
	visible = true

func on_start():
	visible = false
