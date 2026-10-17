extends Control

var car_body := PackedVector2Array([
	Vector2(-19, -4), Vector2(-19, -11), Vector2(-5, -11), Vector2(-4, -19),
	Vector2(6, -19), Vector2(11, -12), Vector2(18, -11), Vector2(19, -6), Vector2(19, -4),
])
var car_window := PackedVector2Array([
	Vector2(-2, -12), Vector2(-1.5, -17), Vector2(5, -17), Vector2(9, -12),
])
var wheels := [Vector2(-11, -4), Vector2(11, -4)]
const WHEEL_RADIUS := 4.5

@export var color := Color(1, 1, 1, 0.95)
@export var track_alpha := 0.18
@export var trail_length := 1.6
@export var trail_steps := 12
@export var track_width := 3.0
@export var car_scale := 1.5
@export var window_color := Color(0, 0, 0, 0.55)
@export var speed := 3.5

var _angle := 0.0


func _process(delta: float) -> void:
	_angle = wrapf(_angle + speed * delta, 0.0, TAU)
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 21.0 * car_scale

	draw_arc(center, radius, 0.0, TAU, 64, Color(color, color.a * track_alpha), track_width, true)

	var step := trail_length / trail_steps
	for i in trail_steps:
		var from := _angle - trail_length + step * i
		var alpha := color.a * float(i + 1) / trail_steps
		draw_arc(center, radius, from, from + step, 6, Color(color, alpha), track_width, true)

	var position_on_ring := center + Vector2.from_angle(_angle) * radius
	draw_set_transform(position_on_ring, _angle + PI / 2.0, Vector2.ONE * car_scale)
	draw_colored_polygon(car_body, color)
	draw_colored_polygon(car_window, window_color)
	for wheel in wheels:
		draw_circle(wheel, WHEEL_RADIUS, color)
		draw_circle(wheel, WHEEL_RADIUS * 0.4, window_color)
	draw_set_transform(Vector2.ZERO)
