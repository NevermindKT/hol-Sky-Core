extends Node
class_name Ground_generator


var world: World
var vegetation: Vegetation_scatter

const SPINE_STEP := 2.0
const PIECE_SAMPLES := 64
const NEEDED_REFRESH_DISTANCE := 16.0

const GROUND_SHADER_PATH := "res://resources/shaders/ground/ground_blend.gdshader"

@export var landscape: LandscapeData

@export_range(0.01, 2.0, 0.01) var texture_tile_scale := 0.2
@export_range(0.0, 1.0, 0.01) var roughness_value := 1.0

@export_group("Terrain")
@export var road_half_width := 8.0
@export var ground_half_width := 1000.0
@export var view_radius := 1000.0
@export var detail_radius := 700.0
@export var chunk_size := 64.0
@export_range(4, 64, 1) var chunk_cells := 16
@export var road_surface_height := 0.05
@export var road_surface_gap := 0.035
@export var height_blend_radius := 40.0
@export var base_blend_distance := 60.0
@export var chunk_behind_distance := 60.0
@export var spine_keep_behind := 1400.0
@export var initial_build_radius := 420.0
@export_range(0, 32, 1) var worker_tasks := 0
@export_range(0.5, 16.0, 0.5) var build_budget_ms := 3.0
@export_range(1, 8, 1) var vegetation_cluster_chunks := 3
@export var detail_release_margin := 100.0

@export_group("Hills")
@export var rolling_height := 5.0
@export var bump_height := 1.2
@export var foothill_height := 18.0
@export var hill_height := 55.0
@export var hill_frequency := 0.003
@export var hill_warp := 70.0
@export_range(0.0, 1.0, 0.01) var ridge_mix := 0.35
@export_range(0.0, 1.0, 0.01) var hill_low := 0.45
@export_range(0.0, 1.0, 0.01) var hill_high := 0.85
@export var region_frequency := 0.0007
@export_range(0.0, 1.0, 0.01) var region_low := 0.5
@export_range(0.0, 1.0, 0.01) var region_high := 0.72
@export var hill_start_distance := 15.0
@export var hill_rise_distance := 90.0


class Surface:
	var cells := 0
	var size := 0.0
	var heights := PackedFloat32Array()
	var distances := PackedFloat32Array()
	var forest := PackedFloat32Array()

	func sample(local_x: float, local_z: float) -> Vector3:
		var n := cells
		var cell := size / float(n)
		var lx := local_x / cell
		var lz := local_z / cell
		var ix := clampi(floori(lx), 0, n - 1)
		var iz := clampi(floori(lz), 0, n - 1)
		var fx := clampf(lx - ix, 0.0, 1.0)
		var fz := clampf(lz - iz, 0.0, 1.0)

		var ring := n + 3
		var hi := (iz + 1) * ring + ix + 1
		var di := iz * (n + 1) + ix

		if fx + fz <= 1.0:
			var h00 := heights[hi]
			var d00 := distances[di]
			var f00 := forest[di]
			return Vector3(
				h00 + (heights[hi + 1] - h00) * fx + (heights[hi + ring] - h00) * fz,
				d00 + (distances[di + 1] - d00) * fx + (distances[di + n + 1] - d00) * fz,
				f00 + (forest[di + 1] - f00) * fx + (forest[di + n + 1] - f00) * fz
			)

		var h11 := heights[hi + ring + 1]
		var d11 := distances[di + n + 2]
		var f11 := forest[di + n + 2]
		return Vector3(
			h11 + (heights[hi + ring] - h11) * (1.0 - fx) + (heights[hi + 1] - h11) * (1.0 - fz),
			d11 + (distances[di + n + 1] - d11) * (1.0 - fx) + (distances[di + 1] - d11) * (1.0 - fz),
			f11 + (forest[di + n + 1] - f11) * (1.0 - fx) + (forest[di + 1] - f11) * (1.0 - fz)
		)


class Chunk:
	var key: Vector2i
	var node: MeshInstance3D
	var rect: Rect2
	var reach := 0.0
	var surface: Surface
	var grid: Vegetation_scatter.GridCells
	var detailed := false


class Cluster:
	var key: Vector2i
	var node: Node3D
	var members: Dictionary = {}
	var slots: Dictionary = {}


class ChunkJob:
	var key: Vector2i
	var spine: Road_spine
	var candidates: PackedInt32Array
	var detail_only := false
	var with_detail := false
	var stale := false
	var task_id := -1
	var reach := 0.0
	var surface: Surface
	var grid: Vegetation_scatter.GridCells
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var weights := PackedFloat32Array()
	var batches: Array[Vegetation_scatter.Batch] = []
	var cluster_key: Vector2i
	var cluster_offset := Vector2.ZERO


var _spine: Road_spine
var _spine_points := PackedVector3Array()
var _spine_offsets := PackedFloat64Array()
var _spine_global_start := 0

var _chunks: Dictionary = {}
var _queue: Array[Vector2i] = []
var _queued: Dictionary = {}
var _detail_queue: Array[Vector2i] = []
var _detail_pending: Dictionary = {}
var _active: Array[ChunkJob] = []
var _active_keys: Dictionary = {}
var _candidate_cache: Dictionary = {}
var _far_keys: Dictionary = {}
var _material: ShaderMaterial
var _index_buffer := PackedInt32Array()
var _max_tasks := 1
var _clusters: Dictionary = {}
var _dirty_clusters: Dictionary = {}

var _world_seed := 0
var _hill_noise: FastNoiseLite
var _region_noise: FastNoiseLite
var _bump_noise: FastNoiseLite
var _patch_noise: FastNoiseLite
var _edge_noise: FastNoiseLite

var _started := false
var _needed_dirty := true
var _needed_origin := Vector3(INF, INF, INF)


func initialize() -> void:
	_world_seed = randi()
	_max_tasks = worker_tasks if worker_tasks > 0 else clampi(OS.get_processor_count() / 3, 2, 4)
	_build_index_buffer()
	_build_noise()
	_build_material()

	if vegetation and landscape:
		vegetation.preload_categories(landscape.vegetation_categories)

	var curve := world.ground_path.curve
	var old_size := _spine_points.size()
	for i in range(curve.point_count - 1):
		_append_piece(curve, i)
	_commit_spine(old_size)

	Events.segment_spawned.connect(_on_segment_spawned)


func _process(_delta: float) -> void:
	if _spine == null or not _spine.is_valid():
		return

	if not _started:
		_started = true
		_refresh_needed(_car_local())
		_build_initial()

	var car_local := _car_local()
	if _needed_dirty or car_local.distance_to(_needed_origin) > NEEDED_REFRESH_DISTANCE:
		_refresh_needed(car_local)

	_pump(Time.get_ticks_usec() + int(build_budget_ms * 1000.0))


func _exit_tree() -> void:
	for job in _active:
		WorkerThreadPool.wait_for_task_completion(job.task_id)
	_active.clear()
	_active_keys.clear()


func _on_segment_spawned(_segment: Road_segment) -> void:
	var curve := world.ground_path.curve
	if curve.point_count < 2:
		return
	var old_size := _spine_points.size()
	_append_piece(curve, curve.point_count - 2)
	_commit_spine(old_size)


func _append_piece(curve: Curve3D, index: int) -> void:
	var p0 := curve.get_point_position(index)
	var c0 := p0 + curve.get_point_out(index)
	var p1 := curve.get_point_position(index + 1)
	var c1 := p1 + curve.get_point_in(index + 1)

	var lengths := PackedFloat64Array([0.0])
	var prev := p0
	for s in range(1, PIECE_SAMPLES + 1):
		var p := _bezier(p0, c0, c1, p1, float(s) / PIECE_SAMPLES)
		lengths.append(lengths[s - 1] + prev.distance_to(p))
		prev = p

	var total: float = lengths[PIECE_SAMPLES]
	if total <= 0.0:
		return

	if _spine_points.is_empty():
		_spine_points.append(p0)
		_spine_offsets.append(0.0)

	var steps := maxi(1, ceili(total / SPINE_STEP))
	var j := 0
	for s in range(1, steps + 1):
		var target := total * s / steps
		while j < PIECE_SAMPLES - 1 and lengths[j + 1] < target:
			j += 1
		var span: float = lengths[j + 1] - lengths[j]
		var f := 0.0 if span <= 0.0 else clampf((target - lengths[j]) / span, 0.0, 1.0)
		var point := _bezier(p0, c0, c1, p1, (j + f) / PIECE_SAMPLES)
		var last := _spine_points[_spine_points.size() - 1]
		_spine_offsets.append(_spine_offsets[_spine_offsets.size() - 1] + last.distance_to(point))
		_spine_points.append(point)


func _bezier(p0: Vector3, c0: Vector3, c1: Vector3, p1: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + c0 * (3.0 * u * u * t) + c1 * (3.0 * u * t * t) + p1 * (t * t * t)


func _commit_spine(old_size: int) -> void:
	var stride := Road_spine.COARSE_STRIDE
	var changed_from := 0
	if old_size > 0:
		var last_global := _spine_global_start + old_size - 1
		changed_from = (last_global / stride) * stride - _spine_global_start

	if _started:
		var xform := world.world.global_transform
		var removed := 0
		while _spine_points.size() > stride * 2 + 1 and (xform * _spine_points[stride]).z > spine_keep_behind:
			_spine_points = _spine_points.slice(stride)
			_spine_offsets = _spine_offsets.slice(stride)
			_spine_global_start += stride
			removed += stride
		changed_from = maxi(changed_from - removed, 0)

	_spine = Road_spine.new(_spine_points.duplicate(), _spine_offsets.duplicate())
	_candidate_cache.clear()

	if old_size > 0:
		_mark_dirty(changed_from)

	for job in _active:
		if _queued.has(job.key):
			job.stale = true

	_needed_dirty = true


func _mark_dirty(from_index: int) -> void:
	var points := _spine.points
	if from_index >= points.size():
		return

	var bounds := Rect2(points[from_index].x, points[from_index].z, 0.0, 0.0)
	for i in range(from_index + 1, points.size()):
		bounds = bounds.expand(Vector2(points[i].x, points[i].z))

	var car_local := _car_local()
	for key in _far_keys.keys():
		var rect := _chunk_rect(key)
		if _rect_rect_distance(rect, bounds) <= ground_half_width or _car_distance(key, car_local) > view_radius * 2.0:
			_far_keys.erase(key)

	var grow := _cell() + SPINE_STEP
	var keys: Array = _chunks.keys()
	for job in _active:
		if not job.detail_only and not _chunks.has(job.key):
			keys.append(job.key)

	for key in keys:
		var reach: float
		var rect: Rect2
		if _chunks.has(key):
			var chunk: Chunk = _chunks[key]
			reach = chunk.reach
			rect = chunk.rect.grow(grow)
		else:
			reach = INF
			rect = _chunk_rect(key).grow(grow)
		if _rect_rect_distance(rect, bounds) >= reach:
			continue
		for i in range(from_index, points.size()):
			if _rect_point_distance(rect, points[i].x, points[i].z) < reach:
				_enqueue_front(key)
				break


func _build_noise() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _world_seed

	_hill_noise = FastNoiseLite.new()
	_hill_noise.seed = rng.randi()
	_hill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hill_noise.frequency = hill_frequency
	_hill_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hill_noise.fractal_octaves = 4
	_hill_noise.fractal_gain = 0.45
	_hill_noise.domain_warp_enabled = hill_warp > 0.0
	_hill_noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	_hill_noise.domain_warp_amplitude = hill_warp
	_hill_noise.domain_warp_frequency = hill_frequency * 0.85

	_region_noise = FastNoiseLite.new()
	_region_noise.seed = rng.randi()
	_region_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_region_noise.frequency = region_frequency
	_region_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_region_noise.fractal_octaves = 3

	_bump_noise = FastNoiseLite.new()
	_bump_noise.seed = rng.randi()
	_bump_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_bump_noise.frequency = 0.02
	_bump_noise.fractal_type = FastNoiseLite.FRACTAL_NONE

	var patch_frequency := landscape.plains_forest_frequency if landscape else 0.004
	_patch_noise = FastNoiseLite.new()
	_patch_noise.seed = rng.randi()
	_patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_patch_noise.frequency = patch_frequency
	_patch_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_patch_noise.fractal_octaves = 3

	_edge_noise = FastNoiseLite.new()
	_edge_noise.seed = rng.randi()
	_edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_edge_noise.frequency = 0.03
	_edge_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_edge_noise.fractal_octaves = 2


func _build_material() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load(GROUND_SHADER_PATH)
	if landscape:
		_material.set_shader_parameter("shoulder_texture", landscape.shoulder_texture)
		_material.set_shader_parameter("meadow_texture", landscape.meadow_texture)
		_material.set_shader_parameter("forest_texture", landscape.forest_texture)
		_material.set_shader_parameter("forest_tint", landscape.forest_tint)
	_material.set_shader_parameter("uv_scale", texture_tile_scale)
	_material.set_shader_parameter("roughness_value", roughness_value)


func _candidates_for(key: Vector2i) -> PackedInt32Array:
	if _candidate_cache.has(key):
		return _candidate_cache[key]
	var half := chunk_size * 0.5
	var half_extent := half * sqrt(2.0) + _cell() * 1.5
	var extra := maxf(height_blend_radius, Road_spine.REFINE_MARGIN) + 1.0
	var candidates := _spine.gather(key.x * chunk_size + half, key.y * chunk_size + half, half_extent, extra)
	_candidate_cache[key] = candidates
	return candidates


func _evaluate(spine: Road_spine, candidates: PackedInt32Array, x: float, z: float, q: Road_spine.Query, out: PackedFloat32Array) -> void:
	if not spine.query(x, z, candidates, height_blend_radius, q):
		out[0] = 0.0
		out[1] = INF
		out[2] = 0.0
		out[3] = 0.0
		return

	var d := q.hit_distance
	var base := lerpf(q.hit_y, q.smooth_y, smoothstep(road_half_width, road_half_width + base_blend_distance, d))

	var near_fade := smoothstep(road_half_width + hill_start_distance, road_half_width + hill_start_distance + hill_rise_distance, d)
	var shape := (_hill_noise.get_noise_2d(x, z) + 1.0) * 0.5
	var ridged := lerpf(shape, 1.0 - absf(2.0 * shape - 1.0), ridge_mix)
	var region := smoothstep(region_low, region_high, (_region_noise.get_noise_2d(x, z) + 1.0) * 0.5)

	var massif := foothill_height * region * smoothstep(0.15, 0.75, ridged) + hill_height * region * region * smoothstep(hill_low, hill_high, ridged)
	var rolling := rolling_height * smoothstep(0.25, 0.8, shape)
	var bumps := bump_height * (_bump_noise.get_noise_2d(x, z) + 1.0) * 0.5

	out[0] = base + road_surface_height - road_surface_gap + (massif + rolling + bumps) * near_fade
	out[1] = d
	out[2] = q.coarse_distance
	out[3] = _forest_density(x, z, massif)


func _forest_density(x: float, z: float, massif: float) -> float:
	if landscape == null:
		return 0.0
	var ragged := _edge_noise.get_noise_2d(x, z) * landscape.forest_edge_noise
	var on_hills := smoothstep(landscape.forest_foot_height, landscape.forest_full_height, massif)
	var threshold := landscape.plains_forest_threshold
	var patch := smoothstep(threshold, threshold + 0.08, (_patch_noise.get_noise_2d(x, z) + 1.0) * 0.5)
	return clampf(maxf(on_hills, patch) + ragged, 0.0, 1.0)


func sample_chunk(key: Vector2i, local_x: float, local_z: float) -> Vector3:
	var chunk: Chunk = _chunks.get(key)
	if chunk == null or chunk.surface == null:
		return Vector3(0.0, INF, 0.0)
	return chunk.surface.sample(local_x, local_z)


func _cell() -> float:
	return chunk_size / float(chunk_cells)


func _car_local() -> Vector3:
	return world.world.global_transform.affine_inverse() * Vector3.ZERO


func _chunk_rect(key: Vector2i) -> Rect2:
	return Rect2(key.x * chunk_size, key.y * chunk_size, chunk_size, chunk_size)


func _car_distance(key: Vector2i, car_local: Vector3) -> float:
	return _rect_point_distance(_chunk_rect(key), car_local.x, car_local.z)


func _is_behind(key: Vector2i, xform: Transform3D, height: float) -> bool:
	var rect := _chunk_rect(key)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		if (xform * Vector3(corner.x, height, corner.y)).z <= chunk_behind_distance:
			return false
	return true


func _refresh_needed(car_local: Vector3) -> void:
	_needed_dirty = false
	_needed_origin = car_local

	var xform := world.world.global_transform
	var unload_radius := view_radius + chunk_size

	for key in _chunks.keys():
		if _car_distance(key, car_local) > unload_radius or _is_behind(key, xform, car_local.y):
			_unload_chunk(key)

	var half := chunk_size * 0.5
	var half_diag := half * sqrt(2.0)
	var min_x := floori((car_local.x - view_radius) / chunk_size)
	var max_x := floori((car_local.x + view_radius) / chunk_size)
	var min_z := floori((car_local.z - view_radius) / chunk_size)
	var max_z := floori((car_local.z + view_radius) / chunk_size)

	var check_road := ground_half_width < view_radius + chunk_size * 2.0
	var added := false
	for cz in range(min_z, max_z + 1):
		for cx in range(min_x, max_x + 1):
			var key := Vector2i(cx, cz)
			if _chunks.has(key) or _queued.has(key) or _far_keys.has(key) or _active_keys.has(key):
				continue
			if _car_distance(key, car_local) > view_radius:
				continue
			if _is_behind(key, xform, car_local.y):
				continue
			if check_road:
				var road_distance := _spine.nearest_coarse_distance(cx * chunk_size + half, cz * chunk_size + half) - half_diag
				if road_distance > ground_half_width:
					_far_keys[key] = true
					continue
			_queue.append(key)
			_queued[key] = true
			added = true

	if added:
		_queue = _sorted_by_distance(_queue, car_local, true)

	var release_radius := detail_radius + detail_release_margin
	for key in _chunks:
		var chunk: Chunk = _chunks[key]
		if chunk.detailed and not _active_keys.has(key) and _car_distance(key, car_local) > release_radius:
			_release_detail(key)

	var detail_added := false
	for key in _chunks:
		var chunk: Chunk = _chunks[key]
		if chunk.detailed or chunk.grid == null or _detail_pending.has(key) or _active_keys.has(key):
			continue
		if _car_distance(key, car_local) > detail_radius:
			continue
		_detail_queue.append(key)
		_detail_pending[key] = true
		detail_added = true

	if detail_added:
		_detail_queue = _sorted_by_distance(_detail_queue, car_local, false)


func _sorted_by_distance(keys: Array[Vector2i], car_local: Vector3, loaded_first: bool) -> Array[Vector2i]:
	var order := PackedInt64Array()
	order.resize(keys.size())
	for i in keys.size():
		var rank := int(_car_distance(keys[i], car_local) * 16.0)
		if loaded_first and not _chunks.has(keys[i]):
			rank += 1 << 30
		order[i] = (rank << 20) | i
	order.sort()

	var sorted: Array[Vector2i] = []
	sorted.resize(keys.size())
	for i in order.size():
		sorted[i] = keys[order[i] & 0xFFFFF]
	return sorted


func _enqueue_front(key: Vector2i) -> void:
	if _queued.has(key):
		_queue.erase(key)
	_queue.push_front(key)
	_queued[key] = true


func _still_needed(key: Vector2i) -> bool:
	if _chunks.has(key):
		return true
	var car_local := _car_local()
	if _car_distance(key, car_local) > view_radius:
		return false
	return not _is_behind(key, world.world.global_transform, car_local.y)


func _build_initial() -> void:
	var car_local := _car_local()
	var remaining: Array[Vector2i] = []
	var jobs: Array[ChunkJob] = []
	for key in _queue:
		if _car_distance(key, car_local) <= initial_build_radius:
			_queued.erase(key)
			var job := _create_job(key, false)
			job.task_id = WorkerThreadPool.add_task(_run_job.bind(job), true)
			jobs.append(job)
		else:
			remaining.append(key)
	_queue = remaining

	for job in jobs:
		WorkerThreadPool.wait_for_task_completion(job.task_id)
		_apply_job(job)

	for cluster_key in _dirty_clusters.keys():
		_rebuild_cluster(cluster_key)
	_dirty_clusters.clear()


func _pump(deadline: int) -> void:
	var index := 0
	while index < _active.size():
		var job := _active[index]
		if not WorkerThreadPool.is_task_completed(job.task_id):
			index += 1
			continue
		WorkerThreadPool.wait_for_task_completion(job.task_id)
		_active.remove_at(index)
		_active_keys.erase(job.key)
		if not job.stale:
			_apply_job(job)
		if Time.get_ticks_usec() >= deadline:
			break

	var rebuilt := 0
	for cluster_key in _dirty_clusters.keys():
		if rebuilt > 0 and Time.get_ticks_usec() >= deadline:
			break
		_dirty_clusters.erase(cluster_key)
		_rebuild_cluster(cluster_key)
		rebuilt += 1

	if Time.get_ticks_usec() >= deadline:
		return

	while _active.size() < _max_tasks:
		var job := _next_job()
		if job == null:
			return
		job.task_id = WorkerThreadPool.add_task(_run_job.bind(job))
		_active.append(job)
		_active_keys[job.key] = true


func _next_job() -> ChunkJob:
	while not _detail_queue.is_empty():
		var detail_key: Vector2i = _detail_queue.pop_front()
		_detail_pending.erase(detail_key)
		if _active_keys.has(detail_key) or _queued.has(detail_key):
			continue
		var target: Chunk = _chunks.get(detail_key)
		if target != null and not target.detailed and target.grid != null:
			var detail_job := _create_job(detail_key, true)
			detail_job.surface = target.surface
			detail_job.grid = target.grid
			return detail_job

	while not _queue.is_empty():
		var key: Vector2i = _queue.pop_front()
		_queued.erase(key)
		if _active_keys.has(key) or not _still_needed(key):
			continue
		return _create_job(key, false)

	return null


func _create_job(key: Vector2i, detail_only: bool) -> ChunkJob:
	var job := ChunkJob.new()
	job.key = key
	job.detail_only = detail_only
	job.cluster_key = _cluster_key(key)
	var cluster_span := vegetation_cluster_chunks * chunk_size
	job.cluster_offset = Vector2(key.x * chunk_size - job.cluster_key.x * cluster_span, key.y * chunk_size - job.cluster_key.y * cluster_span)
	if not detail_only:
		job.spine = _spine
		job.candidates = _candidates_for(key)
		job.with_detail = _car_distance(key, _car_local()) <= detail_radius
	return job


func _run_job(job: ChunkJob) -> void:
	if not job.detail_only:
		_compute_surface(job)

	if vegetation == null or landscape == null:
		return

	if not job.detail_only:
		job.grid = vegetation.build_grid(job.key, _world_seed, landscape, job.surface)

	var categories := landscape.vegetation_categories
	for i in categories.size():
		var category := categories[i]
		var is_detail := category.placement == VegetationCategoryData.Placement.SCATTER
		if is_detail != job.detail_only and not (is_detail and job.with_detail):
			continue
		job.batches.append_array(vegetation.compute_category(job.key, _world_seed, i, category, job.surface, job.grid, job.cluster_key, job.cluster_offset))


func _compute_surface(job: ChunkJob) -> void:
	var n := chunk_cells
	var ring := n + 3
	var cell := _cell()
	var inner := (n + 1) * (n + 1)

	var surface := Surface.new()
	surface.cells = n
	surface.size = chunk_size
	surface.heights.resize(ring * ring)
	surface.distances.resize(inner)
	surface.forest.resize(inner)

	var q := Road_spine.Query.new()
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var reach := 0.0

	for row in ring:
		var iz := row - 1
		var z := float(job.key.y * n + iz) * cell
		var inner_row := iz >= 0 and iz <= n
		for c in ring:
			var ix := c - 1
			var x := float(job.key.x * n + ix) * cell
			_evaluate(job.spine, job.candidates, x, z, q, out)
			surface.heights[row * ring + c] = out[0]
			reach = maxf(reach, out[2])
			if inner_row and ix >= 0 and ix <= n:
				var vi := iz * (n + 1) + ix
				surface.distances[vi] = out[1]
				surface.forest[vi] = out[3]

	var shoulder_width := landscape.shoulder_width if landscape else 3.0
	var shoulder_fade := landscape.shoulder_fade if landscape else 10.0
	var shoulder_start := road_half_width + shoulder_width

	job.vertices.resize(inner)
	job.normals.resize(inner)
	job.uvs.resize(inner)
	job.weights.resize(inner * 4)
	var heights := surface.heights

	for iz in range(n + 1):
		for ix in range(n + 1):
			var vi := iz * (n + 1) + ix
			var hi := (iz + 1) * ring + ix + 1
			job.vertices[vi] = Vector3(ix * cell, heights[hi], iz * cell)
			job.normals[vi] = Vector3(heights[hi - 1] - heights[hi + 1], 2.0 * cell, heights[hi - ring] - heights[hi + ring]).normalized()
			job.uvs[vi] = Vector2(float(job.key.x * n + ix) * cell, float(job.key.y * n + iz) * cell)
			job.weights[vi * 4] = 1.0 - smoothstep(shoulder_start, shoulder_start + shoulder_fade, surface.distances[vi])
			job.weights[vi * 4 + 1] = surface.forest[vi]

	job.surface = surface
	job.reach = reach + maxf(height_blend_radius, Road_spine.REFINE_MARGIN) + SPINE_STEP


func _apply_job(job: ChunkJob) -> void:
	if job.detail_only:
		var target: Chunk = _chunks.get(job.key)
		if target == null or target.surface != job.surface or target.detailed:
			return
		var members: Array = _cluster_for(job.key).members.get(job.key, [])
		members.append_array(job.batches)
		_cluster_for(job.key).members[job.key] = members
		_dirty_clusters[_cluster_key(job.key)] = true
		target.detailed = true
		return

	if not _still_needed(job.key):
		return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = job.vertices
	arrays[Mesh.ARRAY_NORMAL] = job.normals
	arrays[Mesh.ARRAY_TEX_UV] = job.uvs
	arrays[Mesh.ARRAY_CUSTOM0] = job.weights
	arrays[Mesh.ARRAY_INDEX] = _index_buffer

	var format := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)

	var chunk: Chunk = _chunks.get(job.key)
	if chunk == null:
		chunk = Chunk.new()
		chunk.key = job.key
		chunk.rect = _chunk_rect(job.key)
		chunk.node = MeshInstance3D.new()
		chunk.node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		chunk.node.position = Vector3(job.key.x * chunk_size, 0.0, job.key.y * chunk_size)
		chunk.node.material_override = _material
		world.ground_container.add_child(chunk.node)
		_chunks[job.key] = chunk

	chunk.node.mesh = mesh
	chunk.surface = job.surface
	chunk.grid = job.grid
	chunk.reach = job.reach
	chunk.detailed = job.with_detail

	var batches: Array = []
	batches.append_array(job.batches)
	_cluster_for(job.key).members[job.key] = batches
	_dirty_clusters[_cluster_key(job.key)] = true


func _unload_chunk(key: Vector2i) -> void:
	var chunk: Chunk = _chunks[key]
	chunk.node.queue_free()
	_chunks.erase(key)
	for job in _active:
		if job.key == key:
			job.stale = true

	var cluster_key := _cluster_key(key)
	var cluster: Cluster = _clusters.get(cluster_key)
	if cluster != null and cluster.members.erase(key):
		_dirty_clusters[cluster_key] = true


func _release_detail(key: Vector2i) -> void:
	var chunk: Chunk = _chunks[key]
	chunk.detailed = false
	var cluster: Cluster = _clusters.get(_cluster_key(key))
	if cluster == null or not cluster.members.has(key):
		return
	var kept: Array = []
	for batch in cluster.members[key]:
		if batch.category.placement == VegetationCategoryData.Placement.GRID:
			kept.append(batch)
	cluster.members[key] = kept
	_dirty_clusters[cluster.key] = true


func _cluster_key(key: Vector2i) -> Vector2i:
	var g := vegetation_cluster_chunks
	return Vector2i(floori(float(key.x) / g), floori(float(key.y) / g))


func _cluster_for(key: Vector2i) -> Cluster:
	var cluster_key := _cluster_key(key)
	var cluster: Cluster = _clusters.get(cluster_key)
	if cluster == null:
		cluster = Cluster.new()
		cluster.key = cluster_key
		cluster.node = Node3D.new()
		cluster.node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var span := vegetation_cluster_chunks * chunk_size
		cluster.node.position = Vector3(cluster_key.x * span, 0.0, cluster_key.y * span)
		world.ground_container.add_child(cluster.node)
		_clusters[cluster_key] = cluster
	return cluster


func _rebuild_cluster(cluster_key: Vector2i) -> void:
	var cluster: Cluster = _clusters.get(cluster_key)
	if cluster == null:
		return

	if cluster.members.is_empty():
		cluster.node.queue_free()
		_clusters.erase(cluster_key)
		return

	var merged: Dictionary = {}
	for member in cluster.members.values():
		for batch in member:
			if batch.count == 0:
				continue
			var slot_key: int = batch.mesh.get_instance_id()
			var entry: Array = merged.get(slot_key, [])
			if entry.is_empty():
				entry = [batch.category, batch.mesh, PackedFloat32Array(), 0]
				merged[slot_key] = entry
			var buffer: PackedFloat32Array = entry[2]
			buffer.append_array(batch.buffer)
			entry[3] += batch.count

	for slot_key in cluster.slots.keys():
		if not merged.has(slot_key):
			cluster.slots[slot_key].queue_free()
			cluster.slots.erase(slot_key)

	for slot_key in merged:
		var entry: Array = merged[slot_key]
		var node: MultiMeshInstance3D = cluster.slots.get(slot_key)
		if node == null:
			node = vegetation.create_node(entry[0], entry[1])
			cluster.node.add_child(node)
			cluster.slots[slot_key] = node
		var mm := node.multimesh
		mm.instance_count = entry[3]
		mm.buffer = entry[2]


func _build_index_buffer() -> void:
	var n := chunk_cells
	var row := n + 1
	_index_buffer = PackedInt32Array()
	for iz in n:
		for ix in n:
			var i00 := iz * row + ix
			var i10 := i00 + 1
			var i01 := i00 + row
			var i11 := i01 + 1
			_index_buffer.append_array([i00, i10, i01, i10, i11, i01])


func _rect_point_distance(rect: Rect2, x: float, z: float) -> float:
	var dx := maxf(maxf(rect.position.x - x, 0.0), x - rect.end.x)
	var dz := maxf(maxf(rect.position.y - z, 0.0), z - rect.end.y)
	return sqrt(dx * dx + dz * dz)


func _rect_rect_distance(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, 0.0), b.position.x - a.end.x)
	var dz := maxf(maxf(a.position.y - b.end.y, 0.0), b.position.y - a.end.y)
	return sqrt(dx * dx + dz * dz)
