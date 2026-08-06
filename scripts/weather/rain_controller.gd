extends Node

@export var rain_particles: GPUParticles3D


func _ready():
	WeatherManager.weather_changed.connect(_on_weather_changed)
	
	if WeatherManager.weather_data && WeatherManager.weather_data.rain:
		apply_data(WeatherManager.weather_data.rain)


func _on_weather_changed():
	if WeatherManager.weather_data && WeatherManager.weather_data.rain:
		apply_data(WeatherManager.weather_data.rain)


func apply_data(data: RainData):
	rain_particles.amount = data.amount
	
	var mesh = rain_particles.draw_pass_1 as QuadMesh
	if mesh:
		mesh.size = Vector2(data.drop_width, data.drop_length)
		
	var shader = rain_particles.material_override as ShaderMaterial
	if shader:
		shader.set_shader_parameter("rain_color", data.rain_color)
		
	rain_particles.emitting = true
