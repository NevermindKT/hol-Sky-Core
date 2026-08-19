extends Node
class_name Vegetation_scatter

class MeshVariant:
	var mesh: Mesh

var _mesh_pool_cache: Dictionary = {}


func initialize() -> void:
	_mesh_pool_cache.clear()


func populate_side(
	tile: Node3D,
	curve: Curve3D,
	start_offset: float,
	tile_length: float,
	anchor: Vector3,
	side_sign: float,
	road_half_width: float,
	ground_half_width: float,
	ground_generator: Ground_generator,
	biome_a: GroundBiomeData,
	biome_b: GroundBiomeData,
	blend: float
) -> void:
	if biome_a:
		for category in biome_a.vegetation_categories:
			_scatter(tile, curve, start_offset, tile_length, anchor, side_sign, road_half_width, ground_half_width, category, 1.0 - blend, ground_generator, biome_a, biome_b, blend)

	if biome_b and blend > 0.0:
		for category in biome_b.vegetation_categories:
			_scatter(tile, curve, start_offset, tile_length, anchor, side_sign, road_half_width, ground_half_width, category, blend, ground_generator, biome_a, biome_b, blend)


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
	weight: float,
	ground_generator: Ground_generator,
	biome_a: GroundBiomeData,
	biome_b: GroundBiomeData,
	blend: float
) -> void:
	var pool := _get_pool(category)
	if pool.is_empty():
		return

	var effective_count := roundi(category.count * weight)
	if effective_count <= 0:
		return

	var variants: Array = []
	var shuffled: Array = pool.duplicate()
	shuffled.shuffle()
	for i in range(min(category.variants_per_tile, shuffled.size())):
		variants.append(shuffled[i])

	var per_variant := ceili(float(effective_count) / variants.size())

	for variant in variants:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variant.mesh

		var instance_xforms: Array[Transform3D] = []
		var attempts := 0
		var max_attempts := per_variant * 25

		while instance_xforms.size() < per_variant and attempts < max_attempts:
			attempts += 1

			var t := _sample_lateral_t(category.density_curve)
			if t < 0.0:
				continue

			var offset: float = start_offset + randf() * tile_length
			var sample: Transform3D = curve.sample_baked_with_rotation(offset)

			var lateral: float = lerp(road_half_width, ground_half_width, t) * side_sign
			var point: Vector3 = sample.origin + sample.basis.x * lateral - anchor

			if ground_generator:
				point.y += ground_generator.sample_height(point.x + anchor.x, point.z + anchor.z, t, biome_a, biome_b, blend)

			var y_rotation := randf_range(0.0, TAU)
			var scale_factor := randf_range(category.scale_range.x, category.scale_range.y)

			instance_xforms.append(Transform3D(
				Basis.IDENTITY.rotated(Vector3.UP, y_rotation).scaled(Vector3.ONE * scale_factor),
				point
			))

		if instance_xforms.is_empty():
			continue

		mm.instance_count = instance_xforms.size()
		for i in range(instance_xforms.size()):
			mm.set_instance_transform(i, instance_xforms[i])

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

	return -1.0


func _get_pool(category: VegetationCategoryData) -> Array:
	if _mesh_pool_cache.has(category):
		return _mesh_pool_cache[category]

	var pool := _load_meshes(category)
	_mesh_pool_cache[category] = pool

	if pool.is_empty():
		push_warning("Vegetation_scatter: категорія '%s' — не знайдено моделей у '%s'" % [category.category_name, category.folder_path])

	return pool


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
