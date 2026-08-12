@tool
extends Node3D

@export var data: WheelContactDustData:
	set(value):
		data = value
		apply_profile()

@export var particles: GPUParticles3D

func _ready():
	apply_profile()

func apply_profile():
	if data == null:
		return

	_apply_particles()
	
func _apply_particles():
	var material := particles.process_material as ParticleProcessMaterial

	material.direction = data.direction
	material.spread = data.spread

	material.initial_velocity_min = data.initial_velocity_min
	material.initial_velocity_max = data.initial_velocity_max

	material.gravity = data.gravity
	material.damping_min = data.damping_min
	material.damping_max = data.damping_max

	particles.amount = data.amount
	particles.lifetime = data.lifetime
