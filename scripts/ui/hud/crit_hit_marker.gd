extends Control
class_name CritHitMarker

@export var crosshair: CanvasItem

@export_group("Color")
@export var crit_color := Color(1.0, 0.35, 0.1)
@export var color_fade_time := 0.35

@export_group("Crosshair Punch")
@export var punch_scale := 1.6
@export var punch_rotation_deg := 45.0
@export var punch_time := 0.3

@export_group("Hit Marker")
@export var marker_time := 0.45
@export var slash_start_radius := 9.0
@export var slash_end_radius := 24.0
@export var slash_start_length := 14.0
@export var slash_end_length := 5.0
@export var slash_width := 3.0

@export_group("Shock Ring")
@export var ring_start_radius := 10.0
@export var ring_end_radius := 36.0
@export var ring_start_width := 4.0
@export var ring_end_width := 1.0

var _progress := 1.0
var _marker_tween: Tween
var _crosshair_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.critical_hit.connect(_on_critical_hit)


func _on_critical_hit(_position: Vector3) -> void:
	_play_marker()
	_play_crosshair_punch()


func _play_marker() -> void:
	if _marker_tween:
		_marker_tween.kill()

	_marker_tween = create_tween().set_ignore_time_scale(true)
	_marker_tween.tween_method(_set_progress, 0.0, 1.0, marker_time)


func _play_crosshair_punch() -> void:
	if !crosshair:
		return

	if crosshair is Control:
		crosshair.pivot_offset = crosshair.size * 0.5

	if _crosshair_tween:
		_crosshair_tween.kill()

	crosshair.modulate = crit_color
	crosshair.scale = Vector2.ONE * punch_scale
	crosshair.rotation = deg_to_rad(punch_rotation_deg)

	_crosshair_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_crosshair_tween.tween_property(crosshair, "scale", Vector2.ONE, punch_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_crosshair_tween.tween_property(crosshair, "rotation", 0.0, punch_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_crosshair_tween.tween_property(crosshair, "modulate", Color.WHITE, color_fade_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	if _progress >= 1.0:
		return

	var center := size * 0.5
	var move := ease(_progress, 0.3)
	var alpha := 1.0 - _progress * _progress

	var color := crit_color
	color.a = alpha

	var radius := lerpf(slash_start_radius, slash_end_radius, move)
	var length := lerpf(slash_start_length, slash_end_length, move)

	for i in 4:
		var dir := Vector2.from_angle(PI * 0.25 + PI * 0.5 * i)
		draw_line(center + dir * radius, center + dir * (radius + length), color, slash_width, true)

	var ring_color := crit_color
	ring_color.a = alpha * 0.6

	var ring_radius := lerpf(ring_start_radius, ring_end_radius, move)
	var ring_width := lerpf(ring_start_width, ring_end_width, move)
	draw_arc(center, ring_radius, 0.0, TAU, 48, ring_color, ring_width, true)
