extends Node3D
class_name WheelDust

@export var particles: Array[WheelParticlesEffect] = []
@export var car: Car_Movement

@export_group("Backward Wind")
@export var upward_lift: float = 0.3
@export var max_wind_speed: float = 12.0
@export_range(0.0, 1.0) var velocity_spread: float = 0.2

@export_group("Speed Density")
@export var min_speed_for_dust: float = 2.0
@export var reference_speed: float = 40.0


func _ready() -> void:
	for p in particles:
		if p == null:
			continue

		_prepare_effect(p.dust)
		_prepare_effect(p.water_drops)

	Events.weather_changed.connect(_on_weather_changed)
	_on_weather_changed()


func _prepare_effect(effect: GPUParticles3D) -> void:
	if effect == null:
		return

	if effect.process_material:
		effect.process_material = effect.process_material.duplicate()

	effect.emitting = false
	effect.amount_ratio = 0.0


func _on_weather_changed() -> void:
	var rain := WeatherManager.weather_data.rain if WeatherManager.weather_data != null else null
	var is_wet := rain != null and rain.enabled

	for p in particles:
		if p == null:
			continue

		if is_wet:
			p.choose_water_drops()
		else:
			p.choose_dust()


func _process(_delta: float) -> void:
	if car == null:
		return

	var wind_magnitude := clampf(car.speed, 0.0, max_wind_speed)
	var world_wind := car.global_transform.basis.z * wind_magnitude
	world_wind.y += upward_lift

	var intensity := 0.0
	var speed_range := reference_speed - min_speed_for_dust
	if speed_range > 0.0 and car.speed > min_speed_for_dust:
		intensity = clampf((car.speed - min_speed_for_dust) / speed_range, 0.0, 1.0)

	for p in particles:
		if p == null || p.chose_effect == null:
			continue

		var effect := p.chose_effect
		var mat := effect.process_material as ParticleProcessMaterial
		if mat:
			var local_wind := effect.global_transform.basis.inverse() * world_wind
			var wind_speed := local_wind.length()

			if wind_speed > 0.001:
				mat.direction = local_wind / wind_speed

			mat.initial_velocity_min = wind_speed * (1.0 - velocity_spread * 0.2)
			mat.initial_velocity_max = wind_speed * (1.0 + velocity_spread * 0.2)

		effect.amount_ratio = clampf(intensity, 0.5, 1.0)
		effect.emitting = intensity > 0.0 && (InputController.accelerating || InputController.braking)
