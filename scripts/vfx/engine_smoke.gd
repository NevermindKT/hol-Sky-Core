extends Node3D
class_name EngineSmoke

@export var particles: GPUParticles3D
@export var status_controller: Player_Status_Controller
@export var car: Car_Movement

@export_group("Health Reaction")
@export_range(0.0, 1.0) var smoke_start_health_ratio: float = 0.5
@export_range(0.0, 1.0) var min_alpha: float = 0.15
@export_range(0.0, 1.0) var max_alpha: float = 1.0

@export_group("World Drift")
@export var upward_lift: float = 0.5
@export var max_wind_speed: float = 12.0
@export_range(0.0, 1.0) var velocity_spread: float = 0.1

var _material: StandardMaterial3D
var _process_material: ParticleProcessMaterial

func _ready() -> void:
	if particles.material_override:
		particles.material_override = particles.material_override.duplicate()
		_material = particles.material_override as StandardMaterial3D

	if particles.process_material:
		particles.process_material = particles.process_material.duplicate()
		_process_material = particles.process_material as ParticleProcessMaterial

	particles.emitting = false
	particles.amount_ratio = 0.0

	Events.player_health_changed.connect(_on_player_health_changed)


func _process(_delta: float) -> void:
	if _process_material == null or car == null:
		return

	var wind_magnitude := clampf(car.speed, 0.0, max_wind_speed)
	var world_wind := car.global_transform.basis.z * wind_magnitude
	world_wind.y += upward_lift

	var local_wind := particles.global_transform.basis.inverse() * world_wind
	var wind_speed := local_wind.length()

	if wind_speed > 0.001:
		_process_material.direction = local_wind / wind_speed

	_process_material.spread = velocity_spread * 90.0
	_process_material.initial_velocity_min = wind_speed * (1.0 - velocity_spread * 0.2)
	_process_material.initial_velocity_max = wind_speed * (1.0 + velocity_spread * 0.2)


func _on_player_health_changed(current_health: float) -> void:
	var health_ratio := current_health / status_controller.max_health
	var intensity := 0.0

	if health_ratio < smoke_start_health_ratio:
		intensity = 1.0 - health_ratio / smoke_start_health_ratio

	particles.emitting = intensity > 0.0
	particles.amount_ratio = intensity

	if _material:
		_material.albedo_color.a = lerpf(min_alpha, max_alpha, intensity)
