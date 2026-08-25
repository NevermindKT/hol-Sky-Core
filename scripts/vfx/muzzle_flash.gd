extends Node3D
class_name Muzzle_flash

@export var particles: GPUParticles3D

func play() -> void:
	particles.restart()
