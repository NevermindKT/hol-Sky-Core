extends Node3D
class_name WheelDust

@export var particles: Array[GPUParticles3D] = []
@export var car: Car_Movement

@export_group("Backward Wind")
@export var upward_lift: float = 0.3
@export var max_wind_speed: float = 12.0
@export_range(0.0, 1.0) var velocity_spread: float = 0.2

@export_group("Speed Density")
@export var min_speed_for_dust: float = 2.0
@export var reference_speed: float = 40.0

var _process_materials: Array[ParticleProcessMaterial] = []

func _ready() -> void:
	for p in particles:
		if p == null:
			_process_materials.append(null)
			continue

		if p.process_material:
			p.process_material = p.process_material.duplicate()

		_process_materials.append(p.process_material as ParticleProcessMaterial)

		p.emitting = false
		p.amount_ratio = 0.0


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

	for i in particles.size():
		var p := particles[i]
		if p == null:
			continue

		var mat := _process_materials[i]
		if mat:
			var local_wind := p.global_transform.basis.inverse() * world_wind
			var wind_speed := local_wind.length()

			if wind_speed > 0.001:
				mat.direction = local_wind / wind_speed

			mat.initial_velocity_min = wind_speed * (1.0 - velocity_spread * 0.2)
			mat.initial_velocity_max = wind_speed * (1.0 + velocity_spread * 0.2)

		p.amount_ratio = clampf(intensity, 0.5, 1.0)
		p.emitting = intensity > 0.0
