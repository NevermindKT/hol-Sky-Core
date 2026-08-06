@tool
extends Node3D

@export var profile: WheelContactEffectProfile:
	set(value):
		profile = value
		apply_profile()

@export var particles: GPUParticles3D

func _ready():
	apply_profile()

func apply_profile():
	if profile == null:
		return

	_apply_particles()
	
func _apply_particles():
	var material := particles.process_material as ParticleProcessMaterial

	material.direction = profile.direction
	material.spread = profile.spread

	material.initial_velocity_min = profile.initial_velocity_min
	material.initial_velocity_max = profile.initial_velocity_max

	material.gravity = profile.gravity
	material.damping_min = profile.damping_min
	material.damping_max = profile.damping_max

	particles.amount = profile.amount
	particles.lifetime = profile.lifetime
