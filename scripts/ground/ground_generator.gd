extends Node
class_name Ground_generator


var world: World
var vegetation: Vegetation_scatter

const TILE_LENGTH := 20.0
const MAX_TILES := 15
const UNLOAD_DISTANCE := 40.0

const ROAD_HALF_WIDTH := 5.0
const GROUND_HALF_WIDTH := 40.0

## Поділ клаптика по довжині — більше поділів точніше повторює вигин на
## поворотах RoadPath.
const LENGTH_STEPS := 12
## Поділ по ширині — впливає і на форму рельєфу (більше поділів = плавніші
## пагорби, менше — грубіші фасети), і на точність текстурного блендингу.
const WIDTH_STEPS := 12

## Шум для форми рельєфу (пагорби/ями). FastNoiseLite — вбудований ресурс
## Godot, редагується прямо в Inspector (тип шуму, частота, seed).
@export var height_noise: FastNoiseLite

## Амплітуда рельєфу відносно дороги: X = 0 біля дороги, 1 на дальньому
## краю; Y = 0 повністю рівно, 1 максимальна амплітуда (height_amplitude).
## Лишіть лівий кінець кривої на Y=0, інакше узбіччя перестане бути рівним
## стиком з дорогою.
@export var height_curve: Curve

## Максимальна висота нерівностей у метрах (на ділянці, де крива дає 1.0).
@export_range(0.0, 10.0, 0.1) var height_amplitude := 1.5


@export var shoulder_texture: Texture2D
@export var ground_texture: Texture2D
@export var shoulder_ground_blend_curve: Curve
@export_range(0.01, 2.0, 0.01) var texture_tile_scale := 0.2

const GROUND_SHADER_PATH := "res://resources/shaders/ground/ground_blend.gdshader"

var tiles: Array[MeshInstance3D] = []
var _next_offset := 0.0
var _shared_material: ShaderMaterial


func initialize() -> void:
	_next_offset = 0.0
	_shared_material = _build_shared_material()
	_try_spawn_next()


func _build_shared_material() -> ShaderMaterial:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load(GROUND_SHADER_PATH)
	shader_material.set_shader_parameter("shoulder_texture", shoulder_texture)
	shader_material.set_shader_parameter("ground_texture", ground_texture)
	shader_material.set_shader_parameter("uv_scale", texture_tile_scale)
	return shader_material


func _process(_delta: float) -> void:
	if tiles.size() < MAX_TILES:
		_try_spawn_next()

	if tiles.size() > 0 and tiles[0].global_position.z > UNLOAD_DISTANCE:
		tiles[0].queue_free()
		tiles.pop_front()


func _try_spawn_next() -> void:
	var curve := world.world_path.curve
	if curve == null:
		return

	var baked_length := curve.get_baked_length()
	if _next_offset + TILE_LENGTH > baked_length:
		return

	var tile := _build_tile(curve, _next_offset)
	world.ground_container.add_child(tile)
	tiles.append(tile)

	_next_offset += TILE_LENGTH


## Будує один MeshInstance3D-клаптик: дві смуги (ліва/права) уздовж
## відрізка кривої [start_offset, start_offset + TILE_LENGTH]
func _build_tile(curve: Curve3D, start_offset: float) -> MeshInstance3D:
	var anchor: Vector3 = curve.sample_baked_with_rotation(start_offset).origin

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_build_side(st, curve, start_offset, 1.0, anchor)   # права сторона
	_build_side(st, curve, start_offset, -1.0, anchor)  # ліва сторона

	st.generate_normals()
	st.generate_tangents()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.position = anchor
	mesh_instance.material_override = _shared_material

	if vegetation:
		vegetation.populate_side(mesh_instance, curve, start_offset, TILE_LENGTH, anchor, 1.0, ROAD_HALF_WIDTH, GROUND_HALF_WIDTH, self)
		vegetation.populate_side(mesh_instance, curve, start_offset, TILE_LENGTH, anchor, -1.0, ROAD_HALF_WIDTH, GROUND_HALF_WIDTH, self)

	return mesh_instance


## side_sign: 1.0 — права сторона дороги, -1.0 — ліва.
## anchor віднімається від кожної вершини, щоб геометрія була локальною
## відносно mesh_instance.position
func _build_side(st: SurfaceTool, curve: Curve3D, start_offset: float, side_sign: float, anchor: Vector3) -> void:
	var rows: Array = []


	var blend_by_j: Array = []
	for j in range(WIDTH_STEPS + 1):
		var t: float = j / float(WIDTH_STEPS)
		blend_by_j.append(_sample_blend(t))

	for i in range(LENGTH_STEPS + 1):
		var offset: float = start_offset + (TILE_LENGTH * i / float(LENGTH_STEPS))
		var sample: Transform3D = curve.sample_baked_with_rotation(offset)
		var row: Array = []

		for j in range(WIDTH_STEPS + 1):
			var t: float = j / float(WIDTH_STEPS)
			var lateral: float = lerp(ROAD_HALF_WIDTH, GROUND_HALF_WIDTH, t) * side_sign
			var point: Vector3 = sample.origin + sample.basis.x * lateral - anchor

			point.y += sample_height(point.x + anchor.x, point.z + anchor.z, t)

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

			var color0 := Color(blend_by_j[j], blend_by_j[j], blend_by_j[j])
			var color1 := Color(blend_by_j[j + 1], blend_by_j[j + 1], blend_by_j[j + 1])

			if side_sign > 0.0:
				st.set_color(color0); st.set_uv(Vector2(u0, v0)); st.add_vertex(a)
				st.set_color(color0); st.set_uv(Vector2(u0, v1)); st.add_vertex(c)
				st.set_color(color1); st.set_uv(Vector2(u1, v0)); st.add_vertex(b)

				st.set_color(color1); st.set_uv(Vector2(u1, v0)); st.add_vertex(b)
				st.set_color(color0); st.set_uv(Vector2(u0, v1)); st.add_vertex(c)
				st.set_color(color1); st.set_uv(Vector2(u1, v1)); st.add_vertex(d)
			else:
				st.set_color(color0); st.set_uv(Vector2(u0, v0)); st.add_vertex(a)
				st.set_color(color1); st.set_uv(Vector2(u1, v0)); st.add_vertex(b)
				st.set_color(color0); st.set_uv(Vector2(u0, v1)); st.add_vertex(c)

				st.set_color(color1); st.set_uv(Vector2(u1, v0)); st.add_vertex(b)
				st.set_color(color1); st.set_uv(Vector2(u1, v1)); st.add_vertex(d)
				st.set_color(color0); st.set_uv(Vector2(u0, v1)); st.add_vertex(c)


## X кривої: 0 біля дороги, 1 на дальньому краю. Якщо крива не призначена —
## лінійний перехід за замовчуванням (той самий t, без спотворень).
func _sample_blend(t: float) -> float:
	if shoulder_ground_blend_curve == null:
		return t
	return clampf(shoulder_ground_blend_curve.sample(t), 0.0, 1.0)


## Публічний — Vegetation_scatter викликає це саме, щоб дерева/камінці/трава
## сідали на реальну висоту рельєфу
func sample_height(world_x: float, world_z: float, t: float) -> float:
	if height_noise == null:
		return 0.0

	var amplitude := height_amplitude
	if height_curve:
		amplitude *= clampf(height_curve.sample(t), 0.0, 1.0)
	else:
		amplitude *= t

	var noise_value := height_noise.get_noise_2d(world_x, world_z)
	var upward_only := (noise_value + 1.0) * 0.5

	return upward_only * amplitude
