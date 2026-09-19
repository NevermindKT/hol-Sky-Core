extends Node3D
class_name Muzzle_flash

@export var particles: Array[GPUParticles3D]
@export var spot_light: Light3D

func play(queue_free: bool = false) -> void:
	for particle in particles:
		particle.restart()
	
	if spot_light:
		spot_light.show()
	await get_tree().create_timer(particles[0].lifetime).timeout
	
	if not queue_free:
		if spot_light:
			spot_light.hide()
	else:
		queue_free()
	
