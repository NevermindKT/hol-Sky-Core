extends CanvasLayer
class_name Loading_Overlay

@export var root: Control
@export var fade_duration := 0.2

var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_screen() -> void:
	_fade_to(1.0)
	await _tween.finished


func hide_screen() -> void:
	_fade_to(0.0)
	await _tween.finished
	visible = false


func _fade_to(alpha: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	visible = true
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(root, "modulate:a", alpha, fade_duration)
