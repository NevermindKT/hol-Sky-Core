extends Node3D
class_name Shell_Ejector

enum ShellType { PISTOL_9MM, RIFLE, BUCKSHOT }


@export_category("Emitters")
@export var car: Car_Movement
@export var emitter_9mm: GPUParticles3D
@export var emitter_rifle: GPUParticles3D
@export var emitter_buckshot: GPUParticles3D

@export_category("Ejection")
@export var eject_direction := Vector3(1.0, 0.6, -0.3)
@export var eject_speed := 3.5
@export var speed_variation := 1.0
@export var direction_spread := 0.25
@export var inherit_car_speed := 1.0


const EMIT_FLAGS := (
	GPUParticles3D.EMIT_FLAG_POSITION
	| GPUParticles3D.EMIT_FLAG_ROTATION_SCALE
	| GPUParticles3D.EMIT_FLAG_VELOCITY
)


func eject(shell_type: ShellType) -> void:
	var emitter := _get_emitter(shell_type)
	if emitter == null:
		return

	emitter.emit_particle(
		global_transform,
		_build_velocity(car.speed),
		Color.WHITE,
		Color.WHITE,
		EMIT_FLAGS
	)


func _build_velocity(car_speed: float) -> Vector3:
	var direction := eject_direction.normalized()
	direction += Vector3(
		randf_range(-direction_spread, direction_spread),
		randf_range(-direction_spread, direction_spread),
		randf_range(-direction_spread, direction_spread)
	)

	var world_direction := (global_basis * direction).normalized()
	var speed := eject_speed + randf_range(-speed_variation, speed_variation)

	var scroll_velocity := global_basis.z * car_speed * inherit_car_speed

	return world_direction * speed + scroll_velocity


func _get_emitter(shell_type: ShellType) -> GPUParticles3D:
	match shell_type:
		ShellType.PISTOL_9MM:
			return emitter_9mm
		ShellType.RIFLE:
			return emitter_rifle
		ShellType.BUCKSHOT:
			return emitter_buckshot
	return null
