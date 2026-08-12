extends Node3D
class_name WeatherZone


@export var rain_particles: GPUParticles3D

const ENTER_RADIUS := 10.0

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
	if RoadManager.car_movement == null:
		return
	if global_position.distance_to(RoadManager.car_movement.global_position) > ENTER_RADIUS:
		return

	_announced = true

	#if _weather_data.rain == null:
		#print("Entered segment at ", global_position, " — rain profile: NONE (emitting=", rain_particles.emitting, ")")
	#else:
		#print(
			#"Entered segment at ", global_position,
			#" — rain profile: ", _weather_data.rain.resource_path,
			#" enabled=", _weather_data.rain.enabled,
			#" amount=", _weather_data.rain.amount,
			#" emitting=", rain_particles.emitting
		#)

	WeatherManager.set_weather(_weather_data)


func apply_weather(data: WeatherData) -> void:
	# Snapshot, not a reference — weather_generator.gd reuses and mutates
	# the same WeatherData object on every future weather change. Without
	# duplicating here, every already-spawned zone would retroactively
	# "see" whatever the generator picks next, same shared-state trap as
	# the QuadMesh/ShaderMaterial one earlier.
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
