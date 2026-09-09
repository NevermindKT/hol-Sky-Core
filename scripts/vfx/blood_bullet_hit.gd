extends Node3D
class_name BloodBulletHit


@export var splash: GPUParticles3D


func _ready() -> void:
	splash.one_shot = true
	splash.emitting = false

func play(hit_position: Vector3, hit_direction: Vector3) -> void:
	global_position = hit_position
	_orient_to(-hit_direction)

	splash.restart()

	get_tree().create_timer(splash.lifetime).timeout.connect(queue_free)


func _orient_to(hit_direction: Vector3) -> void:
	var direction := hit_direction
	direction.y = 0.0

	if direction.length_squared() <= 0.0001:
		return

	look_at(global_position + direction, Vector3.UP)
