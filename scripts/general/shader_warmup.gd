extends Node3D
class_name Shader_Warmup

const DISTANCE := 8.0
const COLUMNS := 6
const SPACING := 2.5
const RENDER_FRAMES := 8
const MAX_RESOURCE_DEPTH := 4

var _visited := {}
var _scenes: Array[PackedScene] = []
var _materials: Array[Material] = []


func run(scan_roots: Array[Node], camera: Camera3D) -> void:
	for node in scan_roots:
		_scan_tree(node)

	camera.add_child(self)
	position = Vector3(0.0, 0.0, -DISTANCE)

	var started := Time.get_ticks_msec()
	var index := 0
	var queue := _scenes.duplicate()
	while not queue.is_empty():
		var scene: PackedScene = queue.pop_front()
		var instance := scene.instantiate()
		if instance is Road_segment:
			instance.free()
			continue
		var before := _scenes.size()
		_scan_tree(instance)
		queue.append_array(_scenes.slice(before))
		_prepare(instance)
		_place(instance, index)
		index += 1

	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.5
	for material in _materials:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = box
		mesh_instance.material_override = material
		_place(mesh_instance, index)
		index += 1

	for i in RENDER_FRAMES:
		await RenderingServer.frame_post_draw

	GameLog.print("[warmup] scenes=%d materials=%d %d ms" % [_scenes.size(), _materials.size(), Time.get_ticks_msec() - started])
	queue_free()


func _place(node: Node, index: int) -> void:
	add_child(node)
	if node is Node3D:
		var column := index % COLUMNS
		var row: int = floori(index / float(COLUMNS))
		(node as Node3D).position = Vector3((column - (COLUMNS - 1) * 0.5) * SPACING, (row % 3 - 1) * SPACING, -floori(row / 3.0) * SPACING)


func _scan_tree(node: Node) -> void:
	_scan_object(node, 0)
	for child in node.get_children():
		_scan_tree(child)


func _scan_object(object: Object, depth: int) -> void:
	var script := object.get_script() as Script
	if script == null:
		return
	for value in script.get_script_constant_map().values():
		_collect(value, depth)
	for property in object.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			_collect(object.get(property.name), depth)


func _collect(value: Variant, depth: int) -> void:
	if value is Array:
		for item in value:
			_collect(item, depth)
		return
	if value is Dictionary:
		for item in value.values():
			_collect(item, depth)
		return
	if not value is Resource or _visited.has(value):
		return
	_visited[value] = true
	if value is PackedScene:
		_scenes.append(value)
	elif value is Material:
		if _is_spatial(value):
			_materials.append(value)
	elif depth < MAX_RESOURCE_DEPTH:
		_scan_object(value, depth + 1)


func _is_spatial(material: Material) -> bool:
	if material is BaseMaterial3D:
		return true
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		return shader != null and shader.get_mode() == Shader.MODE_SPATIAL
	return false


func _prepare(node: Node) -> void:
	node.set_script(null)
	if node is Node3D:
		(node as Node3D).visible = true
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	if node is GPUParticles3D:
		var particles := node as GPUParticles3D
		particles.one_shot = false
		particles.emitting = true
	if node is CPUParticles3D:
		var cpu_particles := node as CPUParticles3D
		cpu_particles.one_shot = false
		cpu_particles.emitting = true
	if node is RigidBody3D:
		(node as RigidBody3D).freeze = true
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is Area3D:
		(node as Area3D).monitoring = false
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).autoplay = false
	if node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).autoplay = false
	if node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).autoplay = false
	if node is AnimationPlayer:
		(node as AnimationPlayer).autoplay = ""
	if node is Light3D:
		(node as Light3D).light_volumetric_fog_energy = 0.0
	if node is Camera3D:
		(node as Camera3D).current = false
	if node is Timer:
		(node as Timer).autostart = false
	for child in node.get_children():
		_prepare(child)
