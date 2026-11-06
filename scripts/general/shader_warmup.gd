extends Node3D
class_name Shader_Warmup

signal completed

const COLUMNS := 6
const SPACING := 2.5
const MAX_RESOURCE_DEPTH := 4
const CANVAS_RECT_SIZE := 16.0

@export_range(1, 60) var render_frames := 8

@export var camera: Camera3D
@export var car: Car_Movement
@export var blood_hit: BloodCarHit
@export var enemy: Encounter_Enemy
@export var mock_hit_point: Marker3D
@export var stroke_point: Marker3D

@export var blood_stroke_scene: PackedScene

@export_file("*.tscn") var game_scene_path := "res://scenes/main.tscn"
@export var collector_distance := 8.0
@export var light_names: Array[String] = ["Sun", "Moon"]
@export var canvas_layer := 99

var _visited := {}
var _scenes: Array[PackedScene] = []
var _materials: Array[Material] = []
var _canvas_materials: Array[Material] = []
var _spatial_root: Node3D
var _canvas_root: CanvasLayer


func _ready() -> void:
	camera.current = true

	await _populate_from_game_scene()

	var hit_position := car.global_position + mock_hit_point.transform.origin
	var hit_direction := Vector3.FORWARD

	blood_hit.play(
		hit_position,
		hit_direction,
		car.speed,
		car
	)

	_warmup_blood_stroke()
	enemy.warmup_effects()

	for i in render_frames:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

	completed.emit()


func _populate_from_game_scene() -> void:
	if ResourceLoader.load_threaded_request(game_scene_path) != OK:
		return
	while ResourceLoader.load_threaded_get_status(game_scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(game_scene_path) as PackedScene
	if packed == null:
		return

	var game := packed.instantiate()
	_copy_lighting(game)

	var scan_roots: Array[Node] = [game]
	for node in get_tree().root.get_children():
		if node != self and node != get_tree().current_scene:
			scan_roots.append(node)
	_visited[load(scene_file_path)] = true
	_populate(scan_roots)

	game.free()


func _copy_lighting(game: Node) -> void:
	var source_environment := game.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if source_environment:
		var world_environment := WorldEnvironment.new()
		world_environment.environment = source_environment.environment
		add_child(world_environment)

	for light_name in light_names:
		var source := game.find_child(light_name, true, false) as DirectionalLight3D
		if source == null:
			continue
		var light := source.duplicate() as DirectionalLight3D
		light.set_script(null)
		light.visible = true
		light.shadow_enabled = true
		light.light_energy = maxf(light.light_energy, 0.5)
		light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
		add_child(light)


func _warmup_blood_stroke() -> void:
	var stroke: Tire_trail_stroke = blood_stroke_scene.instantiate()
	add_child(stroke)
	stroke.global_transform = stroke_point.global_transform

	for i in 10:
		stroke.add_point(Vector3(0.0, 0.0, -i * 0.3))


func _populate(scan_roots: Array[Node]) -> void:
	var started := Time.get_ticks_msec()

	_spatial_root = Node3D.new()
	camera.add_child(_spatial_root)
	_spatial_root.position = Vector3(0.0, 0.0, -collector_distance)

	_canvas_root = CanvasLayer.new()
	_canvas_root.layer = canvas_layer
	add_child(_canvas_root)

	for node in scan_roots:
		_scan_tree(node)

	var index := 0
	var queue := _scenes.duplicate()
	while not queue.is_empty():
		var scene: PackedScene = queue.pop_front()
		var instance := scene.instantiate()
		var before := _scenes.size()
		_scan_tree(instance)
		queue.append_array(_scenes.slice(before))
		if instance is Road_segment or not instance is Node3D:
			instance.free()
			continue
		_prepare(instance)
		_place_spatial(instance, index)
		index += 1

	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.5
	for material in _materials:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = box
		mesh_instance.material_override = material
		_place_spatial(mesh_instance, index)
		index += 1

	for i in _canvas_materials.size():
		var rect := ColorRect.new()
		rect.material = _canvas_materials[i]
		rect.size = Vector2.ONE * CANVAS_RECT_SIZE
		rect.position = Vector2(i * CANVAS_RECT_SIZE, 0.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas_root.add_child(rect)

	GameLog.print("[warmup] scenes=%d materials=%d canvas=%d %d ms" % [_scenes.size(), _materials.size(), _canvas_materials.size(), Time.get_ticks_msec() - started])


func _place_spatial(node: Node, index: int) -> void:
	_spatial_root.add_child(node)
	if node is Node3D:
		var column := index % COLUMNS
		var row: int = floori(index / float(COLUMNS))
		(node as Node3D).position = Vector3((column - (COLUMNS - 1) * 0.5) * SPACING, (row % 3 - 1) * SPACING, -floori(row / 3.0) * SPACING)


func _scan_tree(node: Node) -> void:
	_scan_object(node, 0)
	if node is CanvasItem:
		_collect((node as CanvasItem).material, MAX_RESOURCE_DEPTH)
	if node is GeometryInstance3D:
		_collect((node as GeometryInstance3D).material_override, MAX_RESOURCE_DEPTH)
		_collect((node as GeometryInstance3D).material_overlay, MAX_RESOURCE_DEPTH)
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
	if not is_instance_valid(value) or not value is Resource or _visited.has(value):
		return
	_visited[value] = true
	if value is PackedScene:
		_scenes.append(value)
	elif value is Material:
		match _shader_mode(value):
			Shader.MODE_SPATIAL:
				_materials.append(value)
			Shader.MODE_CANVAS_ITEM:
				_canvas_materials.append(value)
	elif depth < MAX_RESOURCE_DEPTH:
		_scan_object(value, depth + 1)


func _shader_mode(material: Material) -> int:
	if material is BaseMaterial3D:
		return Shader.MODE_SPATIAL
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		if shader:
			return shader.get_mode()
	return -1


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
