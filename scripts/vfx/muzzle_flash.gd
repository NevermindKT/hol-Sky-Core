extends Node3D
class_name Muzzle_flash

@export var particles: Array[GPUParticles3D]
@export var spot_light: Light3D

@export var saved_tint_color := Color(0.4, 0.9, 1.8, 1)
@export var saved_light_color := Color(0.4, 0.6, 1.0, 1)

var _default_colors: Array[Color] = []
var _default_light_color := Color.WHITE

func _ready() -> void:
	for particle in particles:
		var material := particle.process_material as ParticleProcessMaterial
		_default_colors.append(material.color if material else Color.WHITE)

	if spot_light:
		_default_light_color = spot_light.light_color

func play(queue_free: bool = false, size: float = 1.0, saved: bool = false) -> void:
	scale = Vector3.ONE * size

	for i in particles.size():
		var material := particles[i].process_material as ParticleProcessMaterial
		if material:
			material.color = saved_tint_color if saved else _default_colors[i]
		particles[i].restart()

	if spot_light:
		spot_light.light_color = saved_light_color if saved else _default_light_color
		spot_light.show()
	await get_tree().create_timer(particles[0].lifetime).timeout

	if not queue_free:
		if spot_light:
			spot_light.hide()
	else:
		queue_free()
