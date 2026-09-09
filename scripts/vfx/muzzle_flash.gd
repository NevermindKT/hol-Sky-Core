extends Node3D
class_name Muzzle_flash

@export var particles: Array[GPUParticles3D]
@export var spot_light: SpotLight3D

func play() -> void:
	for particle in particles:
		particle.restart()
	
	spot_light.show()
	await get_tree().create_timer(particles[0].lifetime).timeout
	spot_light.hide()
	
