extends CanvasLayer

@export var rect: ColorRect
@export var white_duration := 1.5
@export var hold_duration := 0.5
@export var black_duration := 1.5
@export var cancel_duration := 0.4

var _tween: Tween
var _run_won := false


func _ready() -> void:
	visible = false
	Events.dawn_finished.connect(_on_dawn_finished)
	Events.run_ended.connect(_on_run_ended)


func _on_dawn_finished() -> void:
	if _run_won:
		return

	GameFlow.in_run = false
	rect.color = Color(1, 1, 1, 0)
	visible = true

	_tween = create_tween()
	_tween.tween_property(rect, "color:a", 1.0, white_duration)
	_tween.tween_interval(hold_duration)
	_tween.tween_property(rect, "color", Color.BLACK, black_duration)
	await _tween.finished

	if not _run_won:
		Events.dawn_blackout.emit()


func _on_run_ended() -> void:
	_run_won = true

	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = create_tween()
		_tween.tween_property(rect, "color:a", 0.0, cancel_duration)
