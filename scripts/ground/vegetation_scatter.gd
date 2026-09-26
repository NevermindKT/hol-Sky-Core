extends Node
class_name Vegetation_scatter

class MeshVariant:
	var mesh: Mesh


class GridCells:
	var size := 0
	var cell := 1.0
	var category := PackedInt32Array()
	var x := PackedFloat32Array()
	var y := PackedFloat32Array()
	var z := PackedFloat32Array()
	var scale := PackedFloat32Array()
	var angle := PackedFloat32Array()
	var variant := PackedFloat32Array()
	var radius := PackedFloat32Array()


class Batch:
	var category: VegetationCategoryData
	var mesh: Mesh
	var buffer := PackedFloat32Array()
	var count := 0


var _mesh_pool_cache: Dictionary = {}


func initialize() -> void:
	_mesh_pool_cache.clear()


func preload_categories(categories: Array[VegetationCategoryData]) -> void:
	for category in categories:
		_get_pool(category)


func build_grid(key: Vector2i, world_seed: int, landscape: LandscapeData, surface: Ground_generator.Surface) -> GridCells:
	var n := landscape.grid_cells_per_chunk
	var grid := GridCells.new()
	grid.size = n + 2
	grid.cell = surface.size / float(n)
	var margin := clampf(landscape.grid_margin, 0.0, grid.cell * 0.45)
	var span := grid.cell - 2.0 * margin

	var count := grid.size * grid.size
	grid.category.resize(count)
	grid.x.resize(count)
	grid.y.resize(count)
	grid.z.resize(count)
	grid.scale.resize(count)
	grid.angle.resize(count)
	grid.variant.resize(count)
	grid.radius.resize(count)

	var categories := landscape.vegetation_categories
	var grid_indices: Array[int] = []
	for i in categories.size():
		if categories[i].placement == VegetationCategoryData.Placement.GRID and categories[i].density > 0.0:
			grid_indices.append(i)
	var chances := PackedFloat32Array()
	chances.resize(grid_indices.size())

	var rng := RandomNumberGenerator.new()
	for rz in grid.size:
		for rx in grid.size:
			var c := rz * grid.size + rx
			var gx := key.x * n + rx - 1
			var gz := key.y * n + rz - 1
			rng.seed = hash([world_seed, gx, gz])

			var lx := (rx - 1) * grid.cell + margin + rng.randf() * span
			var lz := (rz - 1) * grid.cell + margin + rng.randf() * span
			var roll := rng.randf()
			var pick := rng.randf()
			var scale_roll := rng.randf()
			grid.angle[c] = rng.randf() * TAU
			grid.variant[c] = rng.randf()
			grid.category[c] = -1

			if grid_indices.is_empty():
				continue

			var ground := surface.sample(lx, lz)
			var total := 0.0
			for g in grid_indices.size():
				var category: VegetationCategoryData = categories[grid_indices[g]]
				chances[g] = clampf(category.density, 0.0, 1.0) * category.weight_for(ground.z, ground.y)
				total += chances[g]
			if total <= 0.0 or roll >= minf(total, 1.0):
				continue

			var target := pick * total
			var chosen := grid_indices.size() - 1
			for g in grid_indices.size():
				target -= chances[g]
				if target < 0.0:
					chosen = g
					break

			var picked: VegetationCategoryData = categories[grid_indices[chosen]]
			var scale := lerpf(picked.scale_range.x, picked.scale_range.y, scale_roll)
			grid.category[c] = grid_indices[chosen]
			grid.x[c] = lx
			grid.z[c] = lz
			grid.y[c] = ground.x - picked.ground_sink * scale
			grid.scale[c] = scale
			grid.radius[c] = picked.footprint_radius * scale

	return grid


func compute_category(key: Vector2i, world_seed: int, category_index: int, category: VegetationCategoryData, surface: Ground_generator.Surface, grid: GridCells, variant_key: Vector2i, offset: Vector2) -> Array[Batch]:
	var batches: Array[Batch] = []
	var pool: Array = _mesh_pool_cache.get(category, [])
	if pool.is_empty() or category.density <= 0.0:
		return batches

	var variant_rng := RandomNumberGenerator.new()
	variant_rng.seed = hash([world_seed, variant_key.x, variant_key.y, category_index, "variants"])

	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, key.x, key.y, category_index])

	var size := surface.size
	var is_grid := category.placement == VegetationCategoryData.Placement.GRID
	var attempts := 0 if is_grid else roundi(category.density * size * size / 100.0)

	var order: Array = range(pool.size())
	for i in range(order.size() - 1, 0, -1):
		var j := variant_rng.randi_range(0, i)
		var swap = order[i]
		order[i] = order[j]
		order[j] = swap
	var variant_count := mini(category.variants_per_chunk, pool.size())

	for v in variant_count:
		var batch := Batch.new()
		batch.category = category
		batch.mesh = pool[order[v]].mesh
		batches.append(batch)

	if is_grid and grid != null:
		for rz in range(1, grid.size - 1):
			for rx in range(1, grid.size - 1):
				var c := rz * grid.size + rx
				if grid.category[c] != category_index:
					continue
				var variant := mini(int(grid.variant[c] * variant_count), variant_count - 1)
				_append_instance(batches[variant], grid.angle[c], grid.scale[c], grid.x[c] + offset.x, grid.y[c], grid.z[c] + offset.y)

	for i in attempts:
		var lx := rng.randf() * size
		var lz := rng.randf() * size
		var roll := rng.randf()
		var variant := rng.randi_range(0, variant_count - 1)
		var angle := rng.randf() * TAU
		var scale := rng.randf_range(category.scale_range.x, category.scale_range.y)

		var ground := surface.sample(lx, lz)
		if roll >= category.weight_for(ground.z, ground.y):
			continue
		if grid != null and _blocked(grid, lx, lz, category.footprint_radius * scale):
			continue

		_append_instance(batches[variant], angle, scale, lx + offset.x, ground.x - category.ground_sink * scale, lz + offset.y)

	return batches


func create_node(category: VegetationCategoryData, mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh

	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mm_instance.multimesh = mm
	if not category.cast_shadows:
		mm_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if category.visibility_range > 0.0:
		mm_instance.visibility_range_end = category.visibility_range
		mm_instance.visibility_range_end_margin = category.visibility_range * 0.15
		mm_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return mm_instance


func _append_instance(batch: Batch, angle: float, scale: float, x: float, y: float, z: float) -> void:
	var c := cos(angle) * scale
	var s := sin(angle) * scale
	batch.buffer.append_array([c, 0.0, s, x, 0.0, scale, 0.0, y, -s, 0.0, c, z])
	batch.count += 1


func _blocked(grid: GridCells, lx: float, lz: float, radius: float) -> bool:
	var cx := floori(lx / grid.cell) + 1
	var cz := floori(lz / grid.cell) + 1
	for rz in range(maxi(cz - 1, 0), mini(cz + 2, grid.size)):
		for rx in range(maxi(cx - 1, 0), mini(cx + 2, grid.size)):
			var c := rz * grid.size + rx
			if grid.category[c] < 0:
				continue
			var dx := grid.x[c] - lx
			var dz := grid.z[c] - lz
			var reach := grid.radius[c] + radius
			if dx * dx + dz * dz < reach * reach:
				return true
	return false


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

	var loaded := {}
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var model_name := file_name.trim_suffix(".import")
		if (model_name.ends_with(".glb") or model_name.ends_with(".gltf")) and not loaded.has(model_name) and _matches(model_name, category.include_patterns):
			loaded[model_name] = true
			var packed := load(dir_path + "/" + model_name) as PackedScene
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


func _matches(file_name: String, patterns: PackedStringArray) -> bool:
	if patterns.is_empty():
		return true
	for pattern in patterns:
		if file_name.contains(pattern):
			return true
	return false


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
