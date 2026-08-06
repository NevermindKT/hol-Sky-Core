extends Node

@export var rain_particles: GPUParticles3D


func _ready():
	WeatherManager.weather_changed.connect(_on_weather_changed)
	
	if WeatherManager.weather_state && WeatherManager.weather_state.rain:
		apply_profile(WeatherManager.weather_state.rain)


func _on_weather_changed():
	if WeatherManager.weather_state && WeatherManager.weather_state.rain:
		apply_profile(WeatherManager.weather_state.rain)


func apply_profile(profile: RainProfile):
	rain_particles.amount = profile.amount
	
	var mesh = rain_particles.draw_pass_1 as QuadMesh
	if mesh:
		mesh.size = Vector2(profile.drop_width, profile.drop_length)
		
	var shader = rain_particles.material_override as ShaderMaterial
	if shader:
		shader.set_shader_parameter("rain_color", profile.rain_color)
		
	rain_particles.emitting = true
