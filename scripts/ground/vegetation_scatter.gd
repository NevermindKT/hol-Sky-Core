extends Node
class_name Vegetation_scatter


@export var categories: Array[VegetationCategoryData] = []

## Дублікат меша моделі з уже притемненими матеріалами на КОЖНІЙ поверхні
## окремо (стовбур і крона — різні поверхні з різними матеріалами, тому
## притемнювати їх треба нарізно, а не одним material_override зверху).
class MeshVariant:
	var mesh: Mesh

## _mesh_pools[i] — пул MeshVariant для categories[i] (той самий індекс).
var _mesh_pools: Array[Array] = []


## Викликається Bootstrap-ом ДО ground_generator.initialize() — інакше
## перший клаптик землі спробує розкидати рослинність по ще порожніх масивах
## (порядок _ready() між сусідніми вузлами Services покладатись не можна).
func initialize() -> void:
	_mesh_pools.clear()

	for category in categories:
		var pool := _load_meshes(category)
		_mesh_pools.append(pool)

		if pool.is_empty():
			push_warning("Vegetation_scatter: категорія '%s' — не знайдено моделей у '%s'" % [category.category_name, category.folder_path])


func populate_side(
	tile: Node3D,
	curve: Curve3D,
	start_offset: float,
	tile_length: float,
	anchor: Vector3,
	side_sign: float,
	road_half_width: float,
	ground_half_width: float,
	ground_generator: Ground_generator
) -> void:
	for i in range(categories.size()):
		_scatter(tile, curve, start_offset, tile_length, anchor, side_sign, road_half_width, ground_half_width, categories[i], _mesh_pools[i], ground_generator)


func _scatter(
	tile: Node3D,
	curve: Curve3D,
	start_offset: float,
	tile_length: float,
	anchor: Vector3,
	side_sign: float,
	road_half_width: float,
	ground_half_width: float,
	category: VegetationCategoryData,
	pool: Array,
	ground_generator: Ground_generator
) -> void:
	if pool.is_empty():
		return

	var variants: Array = []
	var shuffled: Array = pool.duplicate()
	shuffled.shuffle()
	for i in range(min(category.variants_per_tile, shuffled.size())):
		variants.append(shuffled[i])

	var per_variant := ceili(float(category.count) / variants.size())

	for variant in variants:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variant.mesh
		mm.instance_count = per_variant

		for i in range(per_variant):
			var offset: float = start_offset + randf() * tile_length
			var sample: Transform3D = curve.sample_baked_with_rotation(offset)

			var t := _sample_lateral_t(category.density_curve)
			var lateral: float = lerp(road_half_width, ground_half_width, t) * side_sign
			var point: Vector3 = sample.origin + sample.basis.x * lateral - anchor

			if ground_generator:
				point.y += ground_generator.sample_height(point.x + anchor.x, point.z + anchor.z, t)

			var y_rotation := randf_range(0.0, TAU)
			var scale_factor := randf_range(category.scale_range.x, category.scale_range.y)

			var instance_xform := Transform3D(
				Basis.IDENTITY.rotated(Vector3.UP, y_rotation).scaled(Vector3.ONE * scale_factor),
				point
			)
			mm.set_instance_transform(i, instance_xform)

		var mm_instance := MultiMeshInstance3D.new()
		mm_instance.multimesh = mm
		tile.add_child(mm_instance)



func _sample_lateral_t(density_curve: Curve) -> float:
	if density_curve == null:
		return randf()

	const MAX_ATTEMPTS := 8
	for _attempt in range(MAX_ATTEMPTS):
		var t := randf()
		var weight := clampf(density_curve.sample(t), 0.0, 1.0)
		if randf() <= weight:
			return t

	# Крива на всій ширині дає дуже низьку вагу (наприклад, майже пуста) —
	# щоб не втратити інстанс зовсім, повертаємо рівномірний фолбек.
	return randf()


func _load_meshes(category: VegetationCategoryData) -> Array:
	var variants: Array = []
	var dir_path := category.folder_path

	if dir_path.is_empty():
		return variants

	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Vegetation_scatter: не вдалось відкрити папку " + dir_path)
		return variants

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".glb") or file_name.ends_with(".gltf"):
			var packed := load(dir_path + "/" + file_name) as PackedScene
			if packed:
				var instance := packed.instantiate()
				var mesh_instance := _find_mesh_instance(instance)
				if mesh_instance and mesh_instance.mesh:
					var mesh_variant := MeshVariant.new()
					mesh_variant.mesh = _build_darkened_mesh(mesh_instance.mesh, category)
					variants.append(mesh_variant)
				instance.free()
		file_name = dir.get_next()
	dir.list_dir_end()

	return variants


func _build_darkened_mesh(mesh: Mesh, category: VegetationCategoryData) -> Mesh:
	var darkened_mesh: Mesh = mesh.duplicate()

	for i in range(darkened_mesh.get_surface_count()):
		var original := mesh.surface_get_material(i)
		if original == null or not (original is BaseMaterial3D):
			continue

		var darkened := original.duplicate() as BaseMaterial3D
		darkened.albedo_color = Color(
			darkened.albedo_color.r * category.albedo_darken,
			darkened.albedo_color.g * category.albedo_darken,
			darkened.albedo_color.b * category.albedo_darken,
			darkened.albedo_color.a
		)
		darkened.roughness = category.roughness

		darkened_mesh.surface_set_material(i, darkened)

	return darkened_mesh


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found

	return null
