extends Node3D
class_name WeatherZone


@export var rain_particles: GPUParticles3D

const ENTER_RADIUS := 10.0

var road_manager: Road_manager

var _weather_data := WeatherData.new()
var _announced := false


func _ready() -> void:
	var mesh := rain_particles.draw_pass_1 as QuadMesh
	if mesh:
		rain_particles.draw_pass_1 = mesh.duplicate()

	var shader := rain_particles.material_override as ShaderMaterial
	if shader:
		rain_particles.material_override = shader.duplicate()


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
		return

	rain_particles.emitting = rain.enabled
	rain_particles.amount = rain.amount

	var mesh := rain_particles.draw_pass_1 as QuadMesh
	if mesh:
		mesh.size = Vector2(rain.drop_width, rain.drop_length)

	var shader := rain_particles.material_override as ShaderMaterial
	if shader:
		shader.set_shader_parameter("rain_color", rain.rain_color)
