extends Node
class_name Road_generator

var world: World

var road_set: Road_Set
var obstacle_set: Obstacles_set

var last_segment: Road_segment
var segments: Array[Road_segment] = []

var road_dir := 0
var is_spawning := false

var target_anchor: Marker3D

var obstacle_spawn_chance: float

const MAX_SEGMENTS = 46
const UNLOAD_DISTANCE = 40
const MAX_ROAD_DIR_OFFSET = 2


func initialize(_road_set: Road_Set, _obstacle_set: Obstacles_set) -> void:
	road_set = _road_set
	obstacle_set = _obstacle_set
	spawn_start()


func _process(_delta):
	if segments.size() < MAX_SEGMENTS:
		spawn_next()
	
	if segments[0].global_position.z > UNLOAD_DISTANCE:
		segments[0].queue_free()
		segments.pop_front()
		Events.segment_dispawned.emit()


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

	for data in road_set.segments:
		if is_segment_allowed(data):
			allowed_segments.append(data)

	if allowed_segments.is_empty():
		return road_set.segments[0].scene

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

	if last_segment != null:
		new_segment.transform = (
			last_segment.transform
			* last_segment.anchor.transform
			* new_segment.origin.transform.affine_inverse()
		)

	add_curve_points(new_segment)
	spawn_obstacle(new_segment)
	
	last_segment = new_segment
	
	Events.segment_spawned.emit(new_segment)
	
	match new_segment.segment_type:
		RoadType.Type.LEFT:
			road_dir -= 1
		RoadType.Type.RIGHT:
			road_dir += 1


func spawn_obstacle(segment: Road_segment) -> void:
	if segment.obstacle_placement_array.is_empty():
		return

	if randf() > obstacle_spawn_chance:
		return

	var marker: Marker3D = segment.obstacle_placement_array.pick_random()
	var data: ObstacleData = obstacle_set.obstacles[0]

	var obstacle: Node3D = data.obstacle_scene.instantiate()
	segment.add_child(obstacle)

	obstacle.transform = marker.transform


func is_segment_allowed(data: RoadSegmentData) -> bool:
	var new_dir := road_dir

	match data.type:
		RoadType.Type.LEFT:
			new_dir -= 1

		RoadType.Type.RIGHT:
			new_dir += 1

	return abs(new_dir) <= MAX_ROAD_DIR_OFFSET


func spawn_start():
	spawn(road_set.segments[0].scene)


func spawn_next():
	var scene := pick_random_segment()
	spawn(scene)
