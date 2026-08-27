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

var debug_path: ImmediateMesh
var debug_mesh: MeshInstance3D

const MAX_SEGMENTS = 15
const UNLOAD_DISTANCE = 75
const MAX_ROAD_DIR_OFFSET = 2

var control_points: PackedVector3Array = []


func initialize(_road_set: Road_Set, _obstacle_set: Obstacles_set) -> void:
	road_set = _road_set
	obstacle_set = _obstacle_set
	spawn_start()
	#create_debug_path()


func _process(_delta):
	if segments.size() < MAX_SEGMENTS:
		spawn_next()
	
	if segments[0].global_position.z > UNLOAD_DISTANCE:
		segments[0].queue_free()
		segments.pop_front()
		#_trim_cosmetic_curve_front()
		Events.segment_dispawned.emit()


func create_debug_path() -> void:
	debug_path = ImmediateMesh.new()

	debug_mesh = MeshInstance3D.new()
	debug_mesh.mesh = debug_path

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 0, 1)
	mat.no_depth_test = true
	mat.render_priority = 10

	debug_mesh.material_override = mat

	world.world.add_child(debug_mesh)


func update_debug_path() -> void:
	if debug_path == null:
		return

	var curve := world.world_path.curve

	if curve == null or curve.get_baked_length() <= 0.0:
		return

	debug_path.clear_surfaces()

	debug_path.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	var baked_length := curve.get_baked_length()
	var step := 1.0

	for distance in range(0, int(baked_length), int(step)):
		var point := curve.sample_baked(distance)

		debug_path.surface_set_normal(Vector3.UP)
		debug_path.surface_set_uv(Vector2.ZERO)
		debug_path.surface_add_vertex(point)

	debug_path.surface_end()


func add_curve_points(seg: Road_segment) -> void:
	var origin_xform: Transform3D = seg.transform * seg.origin.transform
	var anchor_xform: Transform3D = seg.transform * seg.anchor.transform
	var curve := world.world_path.curve

	if control_points.is_empty():
		control_points.append(origin_xform.origin)
		curve.add_point(control_points[0])

	control_points.append(anchor_xform.origin)

	var k := control_points.size() - 2
	_place_joint(curve, k)

	update_debug_path()


func _place_joint(curve: Curve3D, k: int) -> void:
	var p_prev := _cp(k - 1)
	var p_here := _cp(k)
	var p_next := _cp(k + 1)

	var joint_pos: Vector3 = (p_prev + 4.0 * p_here + p_next) / 6.0
	var in_pos: Vector3 = (p_prev + 2.0 * p_here) / 3.0
	var out_pos: Vector3 = (2.0 * p_here + p_next) / 3.0

	if k == 0:
		curve.set_point_out(0, out_pos - curve.get_point_position(0))
		return

	curve.add_point(joint_pos, in_pos - joint_pos, out_pos - joint_pos)


func _cp(idx: int) -> Vector3:
	return control_points[clampi(idx, 0, control_points.size() - 1)]


func add_cosmetic_curve_points(seg: Road_segment) -> void:
	var origin_xform: Transform3D = seg.transform * seg.origin.transform
	var anchor_xform: Transform3D = seg.transform * seg.anchor.transform

	var chord: Vector3 = (anchor_xform.origin - origin_xform.origin).normalized()
	var chord_len: float = origin_xform.origin.distance_to(anchor_xform.origin)
	var handle_len: float = chord_len / 3.0

	if world.ground_path.curve.point_count == 0:
		var origin_dir: Vector3 = -origin_xform.basis.z
		if origin_dir.dot(chord) < 0.0:
			origin_dir = -origin_dir
		world.ground_path.curve.add_point(origin_xform.origin, -origin_dir * handle_len, origin_dir * handle_len)

	var anchor_dir: Vector3 = -anchor_xform.basis.z
	if anchor_dir.dot(chord) < 0.0:
		anchor_dir = -anchor_dir
	world.ground_path.curve.add_point(anchor_xform.origin, -anchor_dir * handle_len, anchor_dir * handle_len)


func _trim_cosmetic_curve_front() -> void:
	if world.ground_path.curve.point_count <= 4:
		return
	world.ground_path.curve.remove_point(0)


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

	if last_segment != null:
		new_segment.transform = (
			last_segment.transform
			* last_segment.anchor.transform
			* new_segment.origin.transform.affine_inverse()
		)
		
	segments.append(new_segment)
	world.road_container.add_child(new_segment)

	add_curve_points(new_segment)
	add_cosmetic_curve_points(new_segment)
	#spawn_obstacle(new_segment)
	
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
