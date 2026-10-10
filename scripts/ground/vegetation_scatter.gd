extends Node
class_name Vegetation_scatter

const FOLIAGE_CUTOUT_SHADER := preload("res://resources/shaders/vegetation/foliage_cutout.gdshader")
const FOLIAGE_OPAQUE_SHADER := preload("res://resources/shaders/vegetation/foliage_opaque.gdshader")
const LOD_SUFFIX_PATTERN := "_LOD([0-9]+)$"


class MeshVariant:
	var mesh: Mesh
	var offset := Transform3D.IDENTITY
	var lods: Array[Mesh] = []

	func mesh_for(tier: int) -> Mesh:
		return mesh if tier == 0 else lods[tier - 1]


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
	var road := PackedFloat32Array()


class Batch:
	var category: VegetationCategoryData
	var mesh: Mesh
	var offset := Transform3D.IDENTITY
	var per_chunk := false
	var buffer := PackedFloat32Array()
	var count := 0


var _mesh_pool_cache: Dictionary = {}
var _wind_materials: Array[ShaderMaterial] = []
var _texture_cache: Dictionary = {}
var _far_meshes: Dictionary = {}
var _lod_regex := RegEx.create_from_string(LOD_SUFFIX_PATTERN)


func initialize() -> void:
	_mesh_pool_cache.clear()
	_wind_materials.clear()
	_texture_cache.clear()
	_far_meshes.clear()


func set_wind(intensity: float, direction := Vector3(1.0, 0.0, 0.3)) -> void:
	for material in _wind_materials:
		material.set_shader_parameter("wind_intensity", intensity)
		material.set_shader_parameter("wind_direction", direction.normalized())


func preload_categories(categories: Array[VegetationCategoryData]) -> void:
	for category in categories:
		_get_pool(category)


func build_grid(key: Vector2i, world_seed: int, landscape: LandscapeData, surface: Ground_generator.Surface) -> GridCells:
	var n := maxi(1, roundi(surface.size / maxf(landscape.grid_cell_size, 0.5)))
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
	grid.road.resize(count)

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
			grid.road[c] = ground.y

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
	var tiers := 1 + (pool[0] as MeshVariant).lods.size()

	for v in variant_count:
		var mesh_variant: MeshVariant = pool[order[v]]
		for tier in tiers:
			var batch := Batch.new()
			batch.category = category
			batch.mesh = mesh_variant.mesh_for(tier)
			batch.offset = mesh_variant.offset
			batch.per_chunk = tier == 0 and (tiers > 1 or category.visibility_range > 0.0)
			batches.append(batch)

	if is_grid and grid != null:
		for rz in range(1, grid.size - 1):
			for rx in range(1, grid.size - 1):
				var c := rz * grid.size + rx
				if grid.category[c] != category_index:
					continue
				var variant := mini(int(grid.variant[c] * variant_count), variant_count - 1)
				var tier := _tier_for(category, grid.road[c], tiers)
				_append_instance(batches[variant * tiers + tier], grid.angle[c], grid.scale[c], grid.x[c] + offset.x, grid.y[c], grid.z[c] + offset.y)

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

		_append_instance(batches[variant * tiers + _tier_for(category, ground.y, tiers)], angle, scale, lx + offset.x, ground.x - category.ground_sink * scale, lz + offset.y)

	return batches


func _tier_for(category: VegetationCategoryData, road_distance: float, tiers: int) -> int:
	var tier := 0
	for i in tiers - 1:
		if road_distance >= category.lod_road_distances[i]:
			tier = i + 1
	return tier


func create_node(category: VegetationCategoryData, mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh

	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mm_instance.multimesh = mm
	mm_instance.lod_bias = category.lod_bias
	if not category.cast_shadows or _far_meshes.has(mesh):
		mm_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if category.visibility_range > 0.0:
		mm_instance.visibility_range_end = category.visibility_range
		mm_instance.visibility_range_end_margin = category.visibility_range * 0.15
		if category.visibility_fade:
			mm_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return mm_instance


func _append_instance(batch: Batch, angle: float, scale: float, x: float, y: float, z: float) -> void:
	var phase := angle / TAU
	if batch.offset == Transform3D.IDENTITY:
		var c := cos(angle) * scale
		var s := sin(angle) * scale
		batch.buffer.append_array([c, 0.0, s, x, 0.0, scale, 0.0, y, -s, 0.0, c, z, phase, 0.0, 0.0, 0.0])
	else:
		var t := Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * scale), Vector3(x, y, z)) * batch.offset
		var b := t.basis
		batch.buffer.append_array([b.x.x, b.y.x, b.z.x, t.origin.x, b.x.y, b.y.y, b.z.y, t.origin.y, b.x.z, b.y.z, b.z.z, t.origin.z, phase, 0.0, 0.0, 0.0])
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
		if (model_name.ends_with(".glb") or model_name.ends_with(".gltf")) and not loaded.has(model_name):
			loaded[model_name] = true
			var packed := load(dir_path + "/" + model_name) as PackedScene
			if packed:
				var instance := packed.instantiate()
				_collect_variants(instance, model_name, category, variants)
				instance.free()
		file_name = dir.get_next()
	dir.list_dir_end()

	return variants


func _collect_variants(root: Node, model_name: String, category: VegetationCategoryData, variants: Array) -> void:
	var parts: Array = []
	_collect_mesh_instances(root, Transform3D.IDENTITY, parts)

	var best_lod := {}
	for part in parts:
		var lod := _lod_of(part[0].name)
		var base: String = _lod_base(part[0].name)
		best_lod[base] = mini(best_lod.get(base, lod), lod)

	var groups := {}
	var group_order: Array[Vector2i] = []
	for part in parts:
		var mesh_instance: MeshInstance3D = part[0]
		if _lod_of(mesh_instance.name) > best_lod[_lod_base(mesh_instance.name)]:
			continue
		var origin: Vector3 = part[1].origin
		var key := Vector2i(roundi(origin.x * 100.0), roundi(origin.z * 100.0))
		if not groups.has(key):
			groups[key] = []
			group_order.append(key)
		groups[key].append(part)

	for key in group_order:
		var group: Array = groups[key]
		var label := model_name
		for part in group:
			label += "/" + String(part[0].name)
		if not _matches(label, category.include_patterns) or _matches_any(label, category.exclude_patterns):
			continue
		var first_origin: Vector3 = group[0][1].origin
		var variant := _build_variant(group, Vector3(first_origin.x, 0.0, first_origin.z), category)
		if variant:
			variant.lods = _build_lods(variant.mesh, category)
			variants.append(variant)


func _lod_of(node_name: String) -> int:
	var found := _lod_regex.search(node_name)
	return found.get_string(1).to_int() if found else 0


func _lod_base(node_name: String) -> String:
	return _lod_regex.sub(node_name, "")


func _collect_mesh_instances(node: Node, xform: Transform3D, out: Array) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		var child_xform: Transform3D = xform * child.transform
		if child is MeshInstance3D and child.mesh:
			out.append([child, child_xform])
		_collect_mesh_instances(child, child_xform, out)


func _build_variant(group: Array, pivot: Vector3, category: VegetationCategoryData) -> MeshVariant:
	var variant := MeshVariant.new()

	if group.size() == 1:
		var mesh_instance: MeshInstance3D = group[0][0]
		var local: Transform3D = group[0][1]
		local.origin -= pivot
		var mesh: Mesh = mesh_instance.mesh.duplicate()
		var height := mesh.get_aabb().end.y
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, _prepare_material(mesh_instance.get_active_material(i), category, height))
		variant.mesh = mesh
		variant.offset = local
		return variant

	var surfaces: Array = []
	var height := 0.0
	for part in group:
		var mesh_instance: MeshInstance3D = part[0]
		var array_mesh := mesh_instance.mesh as ArrayMesh
		if array_mesh == null:
			continue
		var local: Transform3D = part[1]
		local.origin -= pivot
		for i in array_mesh.get_surface_count():
			var arrays := _transform_arrays(array_mesh.surface_get_arrays(i), local)
			for vertex in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				height = maxf(height, vertex.y)
			surfaces.append([array_mesh.surface_get_primitive_type(i), arrays, mesh_instance.get_active_material(i), array_mesh.surface_get_name(i)])

	if surfaces.is_empty():
		return null

	var merged := ImporterMesh.new()
	for surface in surfaces:
		merged.add_surface(surface[0], surface[1], [], {}, _prepare_material(surface[2], category, height), surface[3])
	merged.generate_lods(25.0, 60.0, [])
	variant.mesh = merged.get_mesh()
	return variant


func _build_lods(mesh: Mesh, category: VegetationCategoryData) -> Array[Mesh]:
	var lods: Array[Mesh] = []
	var count := mini(category.lod_road_distances.size(), category.lod_keep_ratios.size())
	for i in count:
		var reduced := _reduce_mesh(mesh, clampf(category.lod_keep_ratios[i], 0.01, 1.0), i)
		_far_meshes[reduced] = true
		lods.append(reduced)
	return lods


func _reduce_mesh(mesh: Mesh, ratio: float, seed_offset: int) -> Mesh:
	var reduced := ArrayMesh.new()
	var array_mesh := mesh as ArrayMesh
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var material := mesh.surface_get_material(i)
		if array_mesh and array_mesh.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
			reduced.add_surface_from_arrays(array_mesh.surface_get_primitive_type(i), arrays)
		else:
			if arrays[Mesh.ARRAY_INDEX] == null:
				var sequence := PackedInt32Array()
				for v in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
					sequence.append(v)
				arrays[Mesh.ARRAY_INDEX] = sequence
			if _is_cutout(material):
				arrays = _thin_cards(arrays, ratio, seed_offset)
			else:
				arrays = _simplify(arrays, ratio)
			if arrays.is_empty():
				continue
			reduced.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		reduced.surface_set_material(reduced.get_surface_count() - 1, material)
	return reduced


func _is_cutout(material: Material) -> bool:
	if material is ShaderMaterial:
		return (material as ShaderMaterial).shader == FOLIAGE_CUTOUT_SHADER
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	return false


func _simplify(arrays: Array, ratio: float) -> Array:
	var full: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(25.0, 60.0, [])
	var target := full.size() * ratio
	var best := full
	for lod in importer.get_surface_lod_count(0):
		best = importer.get_surface_lod_indices(0, lod)
		if best.size() <= target:
			break
	arrays[Mesh.ARRAY_INDEX] = best
	return arrays


func _thin_cards(arrays: Array, ratio: float, seed_offset: int) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var parent: Array[int] = []
	parent.resize(vertices.size())
	for v in vertices.size():
		parent[v] = v
	for t in range(0, indices.size(), 3):
		for k in range(1, 3):
			var a := indices[t]
			var b := indices[t + k]
			while parent[a] != a:
				parent[a] = parent[parent[a]]
				a = parent[a]
			while parent[b] != b:
				parent[b] = parent[parent[b]]
				b = parent[b]
			if a != b:
				parent[b] = a

	var roots := PackedInt32Array()
	roots.resize(vertices.size())
	for v in vertices.size():
		var r := v
		while parent[r] != r:
			r = parent[r]
		roots[v] = r

	var rng := RandomNumberGenerator.new()
	rng.seed = hash([vertices.size(), indices.size(), seed_offset])
	var keep := {}
	var centers := {}
	var counts := {}
	for v in vertices.size():
		var r := roots[v]
		if not keep.has(r):
			keep[r] = rng.randf() < ratio
			centers[r] = Vector3.ZERO
			counts[r] = 0
		centers[r] += vertices[v]
		counts[r] += 1

	var grow := minf(1.0 / sqrt(ratio), 3.0)
	var remap := PackedInt32Array()
	remap.resize(vertices.size())
	remap.fill(-1)
	var kept_vertices := PackedInt32Array()
	for v in vertices.size():
		if keep[roots[v]]:
			remap[v] = kept_vertices.size()
			kept_vertices.append(v)
	if kept_vertices.is_empty():
		return []

	var new_indices := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		if remap[indices[t]] >= 0:
			new_indices.append_array([remap[indices[t]], remap[indices[t + 1]], remap[indices[t + 2]]])

	var result := []
	result.resize(Mesh.ARRAY_MAX)
	var new_vertices := PackedVector3Array()
	for v in kept_vertices:
		var center: Vector3 = centers[roots[v]] / float(counts[roots[v]])
		new_vertices.append(center + (vertices[v] - center) * grow)
	result[Mesh.ARRAY_VERTEX] = new_vertices
	result[Mesh.ARRAY_INDEX] = new_indices
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var new_normals := PackedVector3Array()
		for v in kept_vertices:
			new_normals.append(normals[v])
		result[Mesh.ARRAY_NORMAL] = new_normals
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var new_tangents := PackedFloat32Array()
		for v in kept_vertices:
			new_tangents.append_array([tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2], tangents[v * 4 + 3]])
		result[Mesh.ARRAY_TANGENT] = new_tangents
	if arrays[Mesh.ARRAY_COLOR] != null:
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var new_colors := PackedColorArray()
		for v in kept_vertices:
			new_colors.append(colors[v])
		result[Mesh.ARRAY_COLOR] = new_colors
	for uv_slot in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if arrays[uv_slot] != null:
			var uvs: PackedVector2Array = arrays[uv_slot]
			var new_uvs := PackedVector2Array()
			for v in kept_vertices:
				new_uvs.append(uvs[v])
			result[uv_slot] = new_uvs
	return result


func _transform_arrays(arrays: Array, xform: Transform3D) -> Array:
	if xform == Transform3D.IDENTITY:
		return arrays

	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] = xform * vertices[i]
	arrays[Mesh.ARRAY_VERTEX] = vertices

	if arrays[Mesh.ARRAY_NORMAL] != null:
		var normal_basis := xform.basis.inverse().transposed()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in normals.size():
			normals[i] = (normal_basis * normals[i]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals

	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in range(0, tangents.size(), 4):
			var tangent := (xform.basis * Vector3(tangents[i], tangents[i + 1], tangents[i + 2])).normalized()
			tangents[i] = tangent.x
			tangents[i + 1] = tangent.y
			tangents[i + 2] = tangent.z
		arrays[Mesh.ARRAY_TANGENT] = tangents

	return arrays


func _prepare_material(material: Material, category: VegetationCategoryData, height: float) -> Material:
	if not material is BaseMaterial3D:
		return material

	var base := material.duplicate() as BaseMaterial3D
	base.albedo_texture = _shared_texture(base.albedo_texture)
	base.normal_texture = _shared_texture(base.normal_texture)
	base.roughness_texture = _shared_texture(base.roughness_texture)
	base.metallic_texture = _shared_texture(base.metallic_texture)
	base.ao_texture = _shared_texture(base.ao_texture)

	base.metallic_specular = category.specular
	var cutout := base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	if category.wind_strength > 0.0:
		return _make_wind_material(base, cutout, category, height)
	if cutout:
		base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		base.alpha_scissor_threshold = category.alpha_cutoff
		base.cull_mode = BaseMaterial3D.CULL_DISABLED
	return base


func _shared_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return texture
	var key := "%s:%d:%d" % [image.get_size(), image.get_format(), hash(image.get_data())]
	if not _texture_cache.has(key):
		_texture_cache[key] = texture
	return _texture_cache[key]


func _make_wind_material(base: BaseMaterial3D, cutout: bool, category: VegetationCategoryData, height: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FOLIAGE_CUTOUT_SHADER if cutout else FOLIAGE_OPAQUE_SHADER

	material.set_shader_parameter("albedo_color", base.albedo_color)
	if base.albedo_texture:
		material.set_shader_parameter("albedo_texture", base.albedo_texture)
	if base.normal_enabled and base.normal_texture:
		material.set_shader_parameter("normal_texture", base.normal_texture)
		material.set_shader_parameter("normal_scale", base.normal_scale)
	if base.roughness_texture:
		material.set_shader_parameter("roughness_texture", base.roughness_texture)
		material.set_shader_parameter("roughness_channel", _channel_mask(base.roughness_texture_channel))
	material.set_shader_parameter("roughness", base.roughness)
	if base.ao_enabled and base.ao_texture:
		material.set_shader_parameter("ao_texture", base.ao_texture)
		material.set_shader_parameter("ao_channel", _channel_mask(base.ao_texture_channel))
		material.set_shader_parameter("ao_light_affect", base.ao_light_affect)
	material.set_shader_parameter("alpha_cutoff", category.alpha_cutoff)
	material.set_shader_parameter("specular_amount", category.specular)
	material.set_shader_parameter("uv1_scale", base.uv1_scale)
	material.set_shader_parameter("uv1_offset", base.uv1_offset)

	material.set_shader_parameter("wind_strength", category.wind_strength)
	material.set_shader_parameter("wind_speed", category.wind_speed)
	material.set_shader_parameter("wind_height", maxf(height, 0.01))

	_wind_materials.append(material)
	return material


func _channel_mask(channel: BaseMaterial3D.TextureChannel) -> Vector4:
	match channel:
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
			return Vector4(0.0, 1.0, 0.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
			return Vector4(0.0, 0.0, 1.0, 0.0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:
			return Vector4(0.0, 0.0, 0.0, 1.0)
		BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE:
			return Vector4(0.333, 0.333, 0.333, 0.0)
	return Vector4(1.0, 0.0, 0.0, 0.0)


func _matches(label: String, patterns: PackedStringArray) -> bool:
	if patterns.is_empty():
		return true
	return _matches_any(label, patterns)


func _matches_any(label: String, patterns: PackedStringArray) -> bool:
	for pattern in patterns:
		if label.contains(pattern):
			return true
	return false
