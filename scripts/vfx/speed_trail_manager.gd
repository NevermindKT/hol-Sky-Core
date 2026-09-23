extends Node
class_name Speed_trail_manager

var world: World
var car_movement: Car_Movement
var visual_effects: Car_Visual_Effects

@export var stroke_scene: PackedScene

@export_category("Trigger")
@export var min_speed_ratio := 0.5
@export var turn_angle_threshold_deg := 6.0


@export_category("Stroke")
@export var max_points_per_stroke := 60
@export var max_active_strokes := 4
@export var fade_duration := 0.4


var trail_point_l: Marker3D
var trail_point_r: Marker3D
var trail_point_l2: Marker3D
var trail_point_r2: Marker3D

var _active_l: Tire_trail_stroke
var _active_r: Tire_trail_stroke
var _active_l2: Tire_trail_stroke
var _active_r2: Tire_trail_stroke
var _active_strokes: Array[Tire_trail_stroke] = []


func initialize(_world: World, _car_movement: Car_Movement) -> void:
	world = _world
	car_movement = _car_movement
	visual_effects = _car_movement.visual_effects

	trail_point_l = car_movement.get_node_or_null("Visual/SpeedTrailPointContainer/SpeedTrailPointL")
	trail_point_r = car_movement.get_node_or_null("Visual/SpeedTrailPointContainer/SpeedTrailPointR")
	trail_point_l2 = car_movement.get_node_or_null("Visual/SpeedTrailPointContainer/SpeedTrailPointL2")
	trail_point_r2 = car_movement.get_node_or_null("Visual/SpeedTrailPointContainer/SpeedTrailPointR2")

	assert(stroke_scene != null, "Speed_trail_manager: не назначен Stroke Scene.")
	assert(trail_point_l != null, "Speed_trail_manager: не найден SpeedTrailPointL под Car/Visual.")
	assert(trail_point_r != null, "Speed_trail_manager: не найден SpeedTrailPointR под Car/Visual.")
	assert(trail_point_l2 != null, "Speed_trail_manager: не найден SpeedTrailPointL2 под Car/Visual.")
	assert(trail_point_r2 != null, "Speed_trail_manager: не найден SpeedTrailPointR2 под Car/Visual.")


#func _process(_delta: float) -> void:
	#if world == null or car_movement == null or stroke_scene == null:
		#return
#
	#var l_active := _should_leave_mark(true)
	#var r_active := _should_leave_mark(false)
#
	#if l_active:
		#_active_l = _record_point(_active_l, trail_point_l)
	#else:
		#_finalize_stroke(_active_l)
		#_active_l = null
#
	#if r_active:
		#_active_r = _record_point(_active_r, trail_point_r)
	#else:
		#_finalize_stroke(_active_r)
		#_active_r = null
#
	#if r_active:
		#_active_r2 = _record_point(_active_r2, trail_point_r2)
	#else:
		#_finalize_stroke(_active_r2)
		#_active_r2 = null
#
	#if l_active:
		#_active_l2 = _record_point(_active_l2, trail_point_l2)
	#else:
		#_finalize_stroke(_active_l2)
		#_active_l2 = null


func _should_leave_mark(is_left: bool) -> bool:
	if car_movement.get_speed_ratio() < min_speed_ratio:
		return false

	var turn_amount := visual_effects.rotation.y
	if absf(turn_amount) < deg_to_rad(turn_angle_threshold_deg):
		return false

	var turning_left := turn_amount > 0.0
	return turning_left != is_left


func _record_point(stroke: Tire_trail_stroke, point: Marker3D) -> Tire_trail_stroke:
	if stroke == null:
		stroke = stroke_scene.instantiate()
		world.trail_container.add_child(stroke)
		stroke.global_transform = point.get_global_transform_interpolated()
		_active_strokes.append(stroke)
		_enforce_strokes_limit()

	var local_point: Vector3 = stroke.global_transform.affine_inverse() * point.get_global_transform_interpolated().origin
	stroke.add_point(local_point)

	if stroke.point_count() >= max_points_per_stroke:
		_finalize_stroke(stroke)
		return null

	return stroke


func _finalize_stroke(stroke: Tire_trail_stroke) -> void:
	if stroke == null:
		return
	_fade_and_free(stroke)


func _enforce_strokes_limit() -> void:
	while _active_strokes.size() > max_active_strokes:
		var oldest: Tire_trail_stroke = _active_strokes.pop_front()
		if oldest == _active_l:
			_active_l = null
		if oldest == _active_r:
			_active_r = null
		if oldest == _active_l2:
			_active_l2 = null
		if oldest == _active_r2:
			_active_r2 = null
		_fade_and_free(oldest)


func _fade_and_free(stroke: Tire_trail_stroke) -> void:
	if not is_instance_valid(stroke):
		return

	if not stroke.material_override:
		stroke.queue_free()
		return

	var tween := stroke.create_tween()
	tween.tween_property(stroke.material_override, "albedo_color:a", 0.0, fade_duration)
	tween.tween_callback(_on_stroke_faded.bind(stroke))


func _on_stroke_faded(stroke: Tire_trail_stroke) -> void:
	_active_strokes.erase(stroke)
	if is_instance_valid(stroke):
		stroke.queue_free()
