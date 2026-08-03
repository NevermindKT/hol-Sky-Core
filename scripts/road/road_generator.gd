extends Node
class_name Road_generator

@export var world: World
@export var road_manager: Road_manager

@export var road_segments: Array[RoadSegmentData]

var last_segment: Road_segment
var segments: Array[Road_segment] = []

var is_spawning := false

var target_anchor: Marker3D

var road_dir := 0
var distance_traveled := 0

const MAX_ROAD_DIR_OFFSET = 2
const MAX_SEGMENTS = 46
const UNLOAD_DISTANCE = 40

signal segment_spawned(segment: Road_segment)


func _ready() -> void:
	spawn_start()


func _process(_delta):
	if segments.size() < MAX_SEGMENTS:
		spawn_next()
	
	if segments[0].global_position.z > UNLOAD_DISTANCE:
		segments[0].queue_free()
		segments.pop_front()


func add_curve_points(seg: Road_segment) -> void:
	var origin_xform: Transform3D = seg.transform * seg.origin.transform
	var anchor_xform: Transform3D = seg.transform * seg.anchor.transform
	var handle_len: float = seg.length / 3.0

	var chord: Vector3 = (anchor_xform.origin - origin_xform.origin).normalized()

	var origin_dir: Vector3 = -origin_xform.basis.z
	if origin_dir.dot(chord) < 0.0:
		origin_dir = -origin_dir

	var anchor_dir: Vector3 = -anchor_xform.basis.z
	if anchor_dir.dot(chord) < 0.0:
		anchor_dir = -anchor_dir

	if world.world_path.curve.point_count == 0:
		world.world_path.curve.add_point(
			origin_xform.origin,
			-origin_dir * handle_len,
			origin_dir * handle_len
		)

	world.world_path.curve.add_point(
		anchor_xform.origin,
		-anchor_dir * handle_len,
		anchor_dir * handle_len
	)


func pick_random_segment() -> PackedScene:
	var allowed_segments: Array[RoadSegmentData] = []

	for data in road_segments:
		if is_segment_allowed(data):
			allowed_segments.append(data)

	if allowed_segments.is_empty():
		return road_segments[0].scene

	var total_weight := 0.0

	for data in allowed_segments:
		total_weight += data.weight

	var random_weight := randf_range(0.0, total_weight)

	var current_weight := 0.0

	for data in allowed_segments:
		current_weight += data.weight

		if random_weight <= current_weight:
			return data.scene

	return allowed_segments[0].scene


func spawn(scene: PackedScene):
	var new_segment: Road_segment = scene.instantiate()

	segments.append(new_segment)
	world.road_container.add_child(new_segment)
	
	#print("Segments spawned: ", distance_traveled)
	#print("Road dir: ", road_dir)
	#distance_traveled += 1

	if last_segment != null:
		new_segment.transform = (
			last_segment.transform
			* last_segment.anchor.transform
			* new_segment.origin.transform.affine_inverse()
		)

	add_curve_points(new_segment)
	last_segment = new_segment
	segment_spawned.emit(new_segment)
	
	match new_segment.segment_type:
		RoadType.Type.LEFT:
			road_dir -= 1
		RoadType.Type.RIGHT:
			road_dir += 1


func is_segment_allowed(data: RoadSegmentData) -> bool:
	var new_dir := road_dir

	match data.type:
		RoadType.Type.LEFT:
			new_dir -= 1

		RoadType.Type.RIGHT:
			new_dir += 1

	return abs(new_dir) <= MAX_ROAD_DIR_OFFSET


func _on_player_entered_segment(segment: Road_segment):
	road_manager.select_segment(segment)


func spawn_start():
	spawn(road_segments[0].scene)


func spawn_next():
	var scene := pick_random_segment()
	spawn(scene)
