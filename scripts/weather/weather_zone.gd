extends Node3D
class_name WeatherZone

var car: Car_Movement
@export var rain_particles: GPUParticles3D
@export var shoulder_fog_left: FogVolume
@export var shoulder_fog_right: FogVolume

const ENTER_RADIUS := 10.0

var road_manager: Road_manager

var _weather_data := WeatherData.new()
var _announced := false

var _shoulder_material_left: FogMaterial
var _shoulder_material_right: FogMaterial


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


func _process(_delta: float) -> void:
	if _announced:
		return
	if road_manager == null or road_manager.car_movement == null:
		return
	if global_position.distance_to(road_manager.car_movement.global_position) > ENTER_RADIUS:
		return

	_announced = true

	#print(
		#"Zone announced at ", global_position,
		#" rain=", (_weather_data.rain.resource_path if _weather_data.rain else "null"),
		#" fog=", (_weather_data.fog.resource_path if _weather_data.fog else "null"),
		#" time=", Time.get_ticks_msec()
	#)

	WeatherManager.set_weather(_weather_data)


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
	var offset := 20.0

	if fog != null:
		density = fog.shoulder_density
		offset = fog.shoulder_offset

	if shoulder_fog_left:
		shoulder_fog_left.visible = density > 0.0
		shoulder_fog_left.position.x = -offset
		if _shoulder_material_left:
			_shoulder_material_left.density = density

	if shoulder_fog_right:
		shoulder_fog_right.visible = density > 0.0
		shoulder_fog_right.position.x = offset
		if _shoulder_material_right:
			_shoulder_material_right.density = density
