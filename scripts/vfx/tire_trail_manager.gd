extends Node
class_name Tire_trail_manager

enum Trigger_mode { TIRE_SKID, BLOOD }

var world: World
var car_movement: Car_Movement
var road_manager: Road_manager

@export var stroke_scene: PackedScene
@export var trigger_mode: Trigger_mode = Trigger_mode.TIRE_SKID

@export_category("Trigger — Tire Skid")
@export var brake_speed_ratio := 0.6
@export var turn_speed_ratio := 0.5
@export var lateral_velocity_threshold := 3.0
@export var angular_velocity_threshold := 0.3

var _bleeding_distance_left := 0.0

@export_category("Stroke")
@export var max_points_per_stroke := 400
@export var max_active_strokes := 12
@export var fade_duration := 1.5
@export var surface_offset := 0.02

var skid_point_l: Marker3D
var skid_point_r: Marker3D
var skid_point_l2: Marker3D
var skid_point_r2: Marker3D

var _active_l: Tire_trail_stroke
var _active_r: Tire_trail_stroke
var _active_l2: Tire_trail_stroke
var _active_r2: Tire_trail_stroke
var _active_strokes: Array[Tire_trail_stroke] = []


func initialize(_world: World, _car_movement: Car_Movement, _road_manager: Road_manager) -> void:
	world = _world
	car_movement = _car_movement
	road_manager = _road_manager

	if trigger_mode == Trigger_mode.BLOOD and not is_in_group("blood_trail_manager"):
		add_to_group("blood_trail_manager")

	skid_point_l = car_movement.get_node_or_null("SkidPointL")
	skid_point_r = car_movement.get_node_or_null("SkidPointR")
	skid_point_l2 = car_movement.get_node_or_null("SkidPointL2")
	skid_point_r2 = car_movement.get_node_or_null("SkidPointR2")

	assert(stroke_scene != null, "TireTrailManager: не призначено Stroke Scene в Inspector.")
	assert(skid_point_l != null, "TireTrailManager: не знайдено SkidPointL під Car.")
	assert(skid_point_r != null, "TireTrailManager: не знайдено SkidPointR під Car.")
	assert(skid_point_l2 != null, "TireTrailManager: не знайдено SkidPointL2 під Car.")
	assert(skid_point_r2 != null, "TireTrailManager: не знайдено SkidPointR2 під Car.")

func _process(delta: float) -> void:
	if world == null or car_movement == null or stroke_scene == null:
		return

	if trigger_mode == Trigger_mode.BLOOD and _bleeding_distance_left > 0.0:
		_bleeding_distance_left = maxf(_bleeding_distance_left - car_movement.speed * delta, 0.0)

	if _should_leave_marks():
		_active_l = _record_point(_active_l, skid_point_l)
		_active_r = _record_point(_active_r, skid_point_r)
		_active_l2 = _record_point(_active_l2, skid_point_l2)
		_active_r2 = _record_point(_active_r2, skid_point_r2)
	else:
		_finalize_stroke(_active_l)
		_finalize_stroke(_active_r)
		_finalize_stroke(_active_l2)
		_finalize_stroke(_active_r2)
		_active_l = null
		_active_r = null
		_active_l2 = null
		_active_r2 = null

	_resnap_strokes_height()


func _resnap_strokes_height() -> void:
	for stroke in _active_strokes:
		if not is_instance_valid(stroke):
			continue

		var pos := stroke.global_position
		pos.y = surface_offset
		stroke.global_position = pos


func start_bleeding(distance: float) -> void:
	_bleeding_distance_left = maxf(_bleeding_distance_left, distance)


func _should_leave_marks() -> bool:
	match trigger_mode:
		Trigger_mode.BLOOD:
			return _bleeding_distance_left > 0.0
		_:
			var speed_ratio := car_movement.get_speed_ratio()
			return _is_braking_hard(speed_ratio) or _is_turning_hard(speed_ratio)


func _is_braking_hard(speed_ratio: float) -> bool:
	return InputController.braking and speed_ratio > brake_speed_ratio


func _is_turning_hard(speed_ratio: float) -> bool:
	if speed_ratio < turn_speed_ratio:
		return false

	var lateral_hard := absf(car_movement.lateral_velocity) > lateral_velocity_threshold
	var road_curve_hard := road_manager != null and absf(road_manager.smoothed_turn_velocity) > angular_velocity_threshold

	return lateral_hard or road_curve_hard


func _record_point(stroke: Tire_trail_stroke, point: Marker3D) -> Tire_trail_stroke:
	if stroke == null:
		stroke = stroke_scene.instantiate()
		world.trail_container.add_child(stroke)
		stroke.global_transform = point.get_global_transform_interpolated()
		_active_strokes.append(stroke)
		_enforce_strokes_limit()

	var local_point: Vector3 = stroke.global_transform.affine_inverse() * point.get_global_transform_interpolated().origin
	local_point.y = 0.0
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
