extends CanvasLayer

@export var rect: ColorRect
@export var white_duration := 1.5
@export var hold_duration := 0.5
@export var black_duration := 1.5


func _ready() -> void:
	visible = false
	Events.dawn_finished.connect(_on_dawn_finished)


func _on_dawn_finished() -> void:
	GameFlow.in_run = false
	rect.color = Color(1, 1, 1, 0)
	visible = true

	var tween := create_tween()
	tween.tween_property(rect, "color:a", 1.0, white_duration)
	tween.tween_interval(hold_duration)
	tween.tween_property(rect, "color", Color.BLACK, black_duration)
	await tween.finished

	Events.dawn_blackout.emit()
