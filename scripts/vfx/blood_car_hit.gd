extends Node3D
class_name BloodCarHit

## Ефект удару машиною по ворогу: обгортка над blood_splash.tscn +
## ShockwaveEffect, яка вміє розташуватись у точці удару й зіграти обидва
## ефекти в напрямку відкидання.

@export var splash: GPUParticles3D
@export var shockwave: ShockwaveEffect
@export_range(10.0, 180.0) var spread: float = 60.0
@export var lifetime: float = 5.0

func _ready() -> void:
	splash.one_shot = true
	splash.emitting = false

	var mat := splash.process_material as ParticleProcessMaterial
	if mat:
		mat = mat.duplicate()
		mat.direction = Vector3.FORWARD
		mat.spread = spread
		splash.process_material = mat

## Розташовує ефект у точці удару, орієнтує вздовж hit_direction і запускає
## бризк одним пострілом.
func play(hit_position: Vector3, hit_direction: Vector3) -> void:
	global_position = hit_position
	_orient_to(hit_direction)

	splash.restart()

	if shockwave:
		shockwave.play()

	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _orient_to(hit_direction: Vector3) -> void:
	var direction := hit_direction
	direction.y = 0.0

	if direction.length_squared() <= 0.0001:
		return

	look_at(global_position + direction, Vector3.UP)
