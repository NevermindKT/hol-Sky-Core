extends Node3D
class_name WeatherZone

var car: Car_Movement
@export var rain_particles: GPUParticles3D
@export var rain_rings: GPUParticles3D
@export var shoulder_fog_left: FogVolume
@export var shoulder_fog_right: FogVolume
@export var shoulder_fog_segments: int = 5
@export var shoulder_fog_overlap: float = 1.15

const ENTER_RADIUS := 10.0

var road_manager: Road_manager

var _weather_data := WeatherData.new()
var _announced := false

var _shoulder_material_left: FogMaterial
var _shoulder_material_right: FogMaterial

var _shoulder_offset := 20.0

var _shoulder_container_left: Node3D
var _shoulder_container_right: Node3D


func _ready() -> void:
	var mesh := rain_particles.draw_pass_1 as QuadMesh
	if mesh:
		rain_particles.draw_pass_1 = mesh.duplicate()

	var shader := rain_particles.material_override as ShaderMaterial
	if shader:
		rain_particles.material_override = shader.duplicate()

	if shoulder_fog_left and shoulder_fog_left.material:
		_shoulder_material_left = (shoulder_fog_left.material as FogMaterial).duplicate()
		shoulder_fog_left.material = _shoulder_material_left

	if shoulder_fog_right and shoulder_fog_right.material:
		_shoulder_material_right = (shoulder_fog_right.material as FogMaterial).duplicate()
		shoulder_fog_right.material = _shoulder_material_right

	_shoulder_container_left = _wrap_in_container(shoulder_fog_left)
	_shoulder_container_right = _wrap_in_container(shoulder_fog_right)


func _process(_delta: float) -> void:
	if _announced:
		return
	if road_manager == null or road_manager.car_movement == null:
		return
	if global_position.distance_to(road_manager.car_movement.global_position) > ENTER_RADIUS:
		return

	_announced = true

	WeatherManager.set_weather(_weather_data)


func _wrap_in_container(template: FogVolume) -> Node3D:
	if template == null:
		return null

	var container := Node3D.new()
	container.name = template.name + "Chain"

	var parent := template.get_parent()
	parent.add_child(container)
	template.reparent(container)

	return container


func apply_road(segment: Road_segment) -> void:
	_apply_rain_length(segment.length)
	_build_shoulder_chain(shoulder_fog_left, _shoulder_container_left, segment, -1.0)
	_build_shoulder_chain(shoulder_fog_right, _shoulder_container_right, segment, 1.0)


func _apply_rain_length(length: float) -> void:
	var rp_material := rain_particles.process_material as ParticleProcessMaterial
	rp_material.emission_box_extents.z = length

	var rings_material := rain_rings.process_material as ParticleProcessMaterial
	rings_material.emission_box_extents.z = length


func _build_shoulder_chain(template: FogVolume, container: Node3D, segment: Road_segment, side: float) -> void:
	if template == null or container == null:
		return

	var segments := 1
	if segment.segment_type != RoadType.Type.STRAIGHT:
		segments = maxi(shoulder_fog_segments, 1)

	for child in container.get_children():
		if child != template:
			child.queue_free()

	var slice_length := (segment.length / float(segments)) * shoulder_fog_overlap
	var slice_size := Vector3(template.size.x, template.size.y, slice_length)

	for i in range(segments):
		var t := (i + 0.5) / float(segments)
		var road_xf := segment.road_transform_at(t)
		var lateral := road_xf.basis.x * (side * _shoulder_offset)

		var slice: FogVolume = template
		if i != 0:
			slice = template.duplicate()
			container.add_child(slice)
			slice.material = template.material

		slice.size = slice_size
		slice.transform = Transform3D(road_xf.basis, road_xf.origin + lateral)


func apply_weather(data: WeatherData) -> void:
	_weather_data = data.duplicate() if data != null else WeatherData.new()
	var rain := _weather_data.rain

	if rain == null:
		rain_particles.emitting = false
	else:
		rain_particles.emitting = rain.enabled
		rain_particles.amount = rain.amount

		var mesh := rain_particles.draw_pass_1 as QuadMesh
		if mesh:
			mesh.size = Vector2(rain.drop_width, rain.drop_length)

		var shader := rain_particles.material_override as ShaderMaterial
		if shader:
			shader.set_shader_parameter("rain_color", rain.rain_color)

	_apply_shoulder_fog(_weather_data.fog)


func _apply_shoulder_fog(fog: FogData) -> void:
	var density := 0.0
	_shoulder_offset = 20.0

	if fog != null:
		density = fog.shoulder_density
		_shoulder_offset = fog.shoulder_offset

	if _shoulder_container_left:
		_shoulder_container_left.visible = density > 0.0
	if _shoulder_container_right:
		_shoulder_container_right.visible = density > 0.0

	if _shoulder_material_left:
		_shoulder_material_left.density = density
	if _shoulder_material_right:
		_shoulder_material_right.density = density
