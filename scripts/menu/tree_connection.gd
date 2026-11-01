@tool
extends Control
class_name TreeConnection

@export_category("Connection")
@export var from_block: TreeBlock:
	set(value):
		from_block = value
		_update_line()

@export var to_block: TreeBlock:
	set(value):
		to_block = value
		_update_line()

@export_category("Style")
@export var line_width := 4.0:
	set(value):
		line_width = value
		_update_line()

@export var inactive_color := Color(0.4, 0.4, 0.4, 0.35):
	set(value):
		inactive_color = value
		_update_line()

@export var active_color := Color(0.2, 0.9, 1.0, 1.0):
	set(value):
		active_color = value
		_update_line()

@export_category("Curve")
@export var curve_strength := 0.25:
	set(value):
		curve_strength = value
		_update_line()

@export var curved := true:
	set(value):
		curved = value
		_update_line()

@export_range(4, 64, 1) var curve_segments := 16:
	set(value):
		curve_segments = value
		_update_line()

var line: Line2D


func _ready() -> void:
	_create_line()
	_update_line()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_line()


func _create_line() -> void:
	if line:
		return

	line = Line2D.new()
	line.width = line_width
	line.default_color = inactive_color
	line.antialiased = true
	line.z_index = -1

	add_child(line)

	if Engine.is_editor_hint():
		line.owner = get_tree().edited_scene_root


func _update_line() -> void:
	if not is_inside_tree():
		return

	if not line:
		_create_line()

	if not is_instance_valid(from_block) or not is_instance_valid(to_block):
		line.clear_points()
		return

	var start_center := _get_block_center(from_block)
	var end_center := _get_block_center(to_block)

	var direction := (end_center - start_center).normalized()

	# Находим точки пересечения с границами блоков.
	var start := _get_rect_edge(from_block, direction)
	var finish := _get_rect_edge(to_block, -direction)

	# Переводим глобальные координаты в локальные.
	var inverse_transform := get_global_transform_with_canvas().affine_inverse()

	start = inverse_transform * start
	finish = inverse_transform * finish

	line.width = line_width
	line.clear_points()

	if curved:
		var middle_x := (start.x + finish.x) / 2.0
		#var middle_y := (start.y + finish.y) / 2.0

		line.add_point(start)
		line.add_point(Vector2(middle_x, start.y))
		line.add_point(Vector2(middle_x, finish.y))
		line.add_point(finish)
	else:
		line.add_point(start)
		line.add_point(finish)


func _get_block_center(block: Control) -> Vector2:
	return block.global_position + block.size / 2.0


func _get_rect_edge(block: Control, direction: Vector2) -> Vector2:
	var center := _get_block_center(block)
	var half_size := block.size / 2.0

	if direction.length_squared() == 0.0:
		return center

	var scale_x := half_size.x / absf(direction.x) if direction.x != 0.0 else INF
	var scale_y := half_size.y / absf(direction.y) if direction.y != 0.0 else INF

	var distance := minf(scale_x, scale_y)

	return center + direction * distance


func set_active(value: bool) -> void:
	if not line:
		return

	line.default_color = active_color if value else inactive_color
