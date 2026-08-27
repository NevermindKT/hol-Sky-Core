extends Node
class_name Ground_generator


var world: World
var vegetation: Vegetation_scatter

const TILE_LENGTH := 20.0
const MAX_TILES := 15
const UNLOAD_DISTANCE := 40.0

const ROAD_HALF_WIDTH := 6.4
const GROUND_HALF_WIDTH := 80.0

const LENGTH_STEPS := 12
const WIDTH_STEPS := 12

const GROUND_SHADER_PATH := "res://resources/shaders/ground/ground_blend.gdshader"

@export var available_biomes: Array[GroundBiomeData] = []

@export var min_tiles_per_biome := 5
@export var max_tiles_per_biome := 12

@export_range(1, 10, 1) var transition_tiles := 3

@export_range(0.01, 2.0, 0.01) var texture_tile_scale := 0.2
@export_range(0.0, 1.0, 0.01) var roughness_value := 1.0

var tiles: Array[MeshInstance3D] = []
var _next_offset := 0.0

var _current_biome: GroundBiomeData
var _next_biome: GroundBiomeData
var _in_transition := false
var _transition_start_offset := 0.0
var _tiles_since_change := 0
var _tiles_until_change := 0


func initialize() -> void:
	_next_offset = 0.0
	_current_biome = null
	_next_biome = null
	_in_transition = false
	_transition_start_offset = 0.0
	_tiles_since_change = 0
	_tiles_until_change = 0
	Events.cosmetic_curve_trimmed.connect(_on_cosmetic_curve_trimmed)
	_try_spawn_next()


func _process(_delta: float) -> void:
	if tiles.size() < MAX_TILES:
		_try_spawn_next()

	if tiles.size() > 0 and tiles[0].global_position.z > UNLOAD_DISTANCE:
		tiles[0].queue_free()
		tiles.pop_front()


func _on_cosmetic_curve_trimmed(removed_length: float) -> void:
	_next_offset -= removed_length
	_transition_start_offset -= removed_length


func _try_spawn_next() -> void:
	var curve := world.ground_path.curve
	if curve == null:
		return

	var baked_length := curve.get_baked_length()
	if _next_offset + TILE_LENGTH > baked_length:
		return

	var state := _advance_biome_state()
	var biome_a: GroundBiomeData = state[0]
	var biome_b: GroundBiomeData = state[1]
	var transition_start: float = state[2]
	var transition_length: float = state[3]

	var tile := _build_tile(curve, _next_offset, biome_a, biome_b, transition_start, transition_length)
	world.ground_container.add_child(tile)
	tiles.append(tile)

	_next_offset += TILE_LENGTH


func _advance_biome_state() -> Array:
	if available_biomes.is_empty():
		return [null, null, 0.0, 0.0]

	var transition_length := float(transition_tiles) * TILE_LENGTH

	if _current_biome == null:
		_current_biome = _pick_random_biome(null)
		_tiles_since_change = 0
		_tiles_until_change = randi_range(min_tiles_per_biome, max_tiles_per_biome)
		return [_current_biome, null, 0.0, 0.0]

	if _in_transition:
		var biome_a := _current_biome
		var biome_b := _next_biome
		var start := _transition_start_offset

		if _next_offset - start >= transition_length:
			_current_biome = _next_biome
			_next_biome = null
			_in_transition = false
			_tiles_since_change = 0
			_tiles_until_change = randi_range(min_tiles_per_biome, max_tiles_per_biome)

		return [biome_a, biome_b, start, transition_length]

	_tiles_since_change += 1
	if _tiles_since_change >= _tiles_until_change and available_biomes.size() > 1:
		_next_biome = _pick_random_biome(_current_biome)
		_in_transition = true
		_transition_start_offset = _next_offset
		return [_current_biome, _next_biome, _next_offset, transition_length]

	return [_current_biome, null, 0.0, 0.0]


func _pick_random_biome(exclude: GroundBiomeData) -> GroundBiomeData:
	var choices := available_biomes
	if exclude != null and available_biomes.size() > 1:
		choices = available_biomes.filter(func(b): return b != exclude)
	return choices[randi() % choices.size()]


func sample_transition_blend(offset: float, biome_b: GroundBiomeData, transition_start: float, transition_length: float) -> float:
	if biome_b == null or transition_length <= 0.0:
		return 0.0
	return clampf((offset - transition_start) / transition_length, 0.0, 1.0)


func _build_tile(curve: Curve3D, start_offset: float, biome_a: GroundBiomeData, biome_b: GroundBiomeData, transition_start: float, transition_length: float) -> MeshInstance3D:
	var anchor: Vector3 = curve.sample_baked_with_rotation(start_offset).origin

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_build_side(st, curve, start_offset, 1.0, anchor, biome_a, biome_b, transition_start, transition_length)
	_build_side(st, curve, start_offset, -1.0, anchor, biome_a, biome_b, transition_start, transition_length)

	st.generate_normals()
	st.generate_tangents()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.position = anchor
	mesh_instance.material_override = _build_tile_material(biome_a, biome_b)

	if vegetation:
		vegetation.populate_side(mesh_instance, curve, start_offset, TILE_LENGTH, anchor, 1.0, ROAD_HALF_WIDTH, GROUND_HALF_WIDTH, self, biome_a, biome_b, transition_start, transition_length)
		vegetation.populate_side(mesh_instance, curve, start_offset, TILE_LENGTH, anchor, -1.0, ROAD_HALF_WIDTH, GROUND_HALF_WIDTH, self, biome_a, biome_b, transition_start, transition_length)

	return mesh_instance


func _build_tile_material(biome_a: GroundBiomeData, biome_b: GroundBiomeData) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(GROUND_SHADER_PATH)

	mat.set_shader_parameter("shoulder_texture_a", biome_a.shoulder_texture if biome_a else null)
	mat.set_shader_parameter("ground_texture_a", biome_a.ground_texture if biome_a else null)

	var texture_biome_b: GroundBiomeData = biome_b if biome_b else biome_a
	mat.set_shader_parameter("shoulder_texture_b", texture_biome_b.shoulder_texture if texture_biome_b else null)
	mat.set_shader_parameter("ground_texture_b", texture_biome_b.ground_texture if texture_biome_b else null)

	mat.set_shader_parameter("uv_scale", texture_tile_scale)
	mat.set_shader_parameter("roughness_value", roughness_value)

	return mat


func _build_side(st: SurfaceTool, curve: Curve3D, start_offset: float, side_sign: float, anchor: Vector3, biome_a: GroundBiomeData, biome_b: GroundBiomeData, transition_start: float, transition_length: float) -> void:
	var rows: Array = []
	var row_blends: Array = []

	var blend_a_by_j: Array = []
	var blend_b_by_j: Array = []
	for j in range(WIDTH_STEPS + 1):
		var t: float = j / float(WIDTH_STEPS)
		blend_a_by_j.append(_sample_biome_shoulder_blend(biome_a, t))
		blend_b_by_j.append(_sample_biome_shoulder_blend(biome_b if biome_b else biome_a, t))

	for i in range(LENGTH_STEPS + 1):
		var offset: float = start_offset + (TILE_LENGTH * i / float(LENGTH_STEPS))
		var sample: Transform3D = curve.sample_baked_with_rotation(offset)
		var row: Array = []

		var row_blend := sample_transition_blend(offset, biome_b, transition_start, transition_length)
		row_blends.append(row_blend)

		for j in range(WIDTH_STEPS + 1):
			var t: float = j / float(WIDTH_STEPS)
			var lateral: float = lerp(ROAD_HALF_WIDTH, GROUND_HALF_WIDTH, t) * side_sign
			var point: Vector3 = sample.origin + sample.basis.x * lateral - anchor

			point.y += sample_height(point.x + anchor.x, point.z + anchor.z, t, biome_a, biome_b, row_blend)

			row.append(point)

		rows.append(row)

	for i in range(LENGTH_STEPS):
		for j in range(WIDTH_STEPS):
			var a: Vector3 = rows[i][j]
			var b: Vector3 = rows[i][j + 1]
			var c: Vector3 = rows[i + 1][j]
			var d: Vector3 = rows[i + 1][j + 1]

			var u0 := (j / float(WIDTH_STEPS)) * (GROUND_HALF_WIDTH - ROAD_HALF_WIDTH)
			var u1 := ((j + 1) / float(WIDTH_STEPS)) * (GROUND_HALF_WIDTH - ROAD_HALF_WIDTH)
			var v0 := start_offset + (TILE_LENGTH * i / float(LENGTH_STEPS))
			var v1 := start_offset + (TILE_LENGTH * (i + 1) / float(LENGTH_STEPS))

			var color_a := Color(blend_a_by_j[j], row_blends[i], blend_b_by_j[j])
			var color_b := Color(blend_a_by_j[j + 1], row_blends[i], blend_b_by_j[j + 1])
			var color_c := Color(blend_a_by_j[j], row_blends[i + 1], blend_b_by_j[j])
			var color_d := Color(blend_a_by_j[j + 1], row_blends[i + 1], blend_b_by_j[j + 1])

			if side_sign > 0.0:
				st.set_color(color_a); st.set_uv(Vector2(u0, v0)); st.add_vertex(a)
				st.set_color(color_c); st.set_uv(Vector2(u0, v1)); st.add_vertex(c)
				st.set_color(color_b); st.set_uv(Vector2(u1, v0)); st.add_vertex(b)

				st.set_color(color_b); st.set_uv(Vector2(u1, v0)); st.add_vertex(b)
				st.set_color(color_c); st.set_uv(Vector2(u0, v1)); st.add_vertex(c)
				st.set_color(color_d); st.set_uv(Vector2(u1, v1)); st.add_vertex(d)
			else:
				st.set_color(color_a); st.set_uv(Vector2(u0, v0)); st.add_vertex(a)
				st.set_color(color_b); st.set_uv(Vector2(u1, v0)); st.add_vertex(b)
				st.set_color(color_c); st.set_uv(Vector2(u0, v1)); st.add_vertex(c)

				st.set_color(color_b); st.set_uv(Vector2(u1, v0)); st.add_vertex(b)
				st.set_color(color_d); st.set_uv(Vector2(u1, v1)); st.add_vertex(d)
				st.set_color(color_c); st.set_uv(Vector2(u0, v1)); st.add_vertex(c)


func _sample_biome_shoulder_blend(biome: GroundBiomeData, t: float) -> float:
	if biome == null or biome.shoulder_ground_blend_curve == null:
		return t
	return clampf(biome.shoulder_ground_blend_curve.sample(t), 0.0, 1.0)


func sample_height(world_x: float, world_z: float, t: float, biome_a: GroundBiomeData, biome_b: GroundBiomeData, blend: float) -> float:
	var height_a := _sample_biome_height(biome_a, world_x, world_z, t)

	if biome_b == null or blend <= 0.0:
		return height_a

	var height_b := _sample_biome_height(biome_b, world_x, world_z, t)
	return lerp(height_a, height_b, blend)


func _sample_biome_height(biome: GroundBiomeData, world_x: float, world_z: float, t: float) -> float:
	if biome == null or biome.height_noise == null:
		return 0.0

	var amplitude := biome.height_amplitude
	if biome.height_curve:
		amplitude *= clampf(biome.height_curve.sample(t), 0.0, 1.0)
	else:
		amplitude *= t

	var noise_value := biome.height_noise.get_noise_2d(world_x, world_z)
	var upward_only := (noise_value + 1.0) * 0.5

	return upward_only * amplitude
