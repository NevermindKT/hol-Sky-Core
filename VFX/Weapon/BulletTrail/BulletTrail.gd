@tool
extends Node3D

@export var profile: BulletTrailProfile:
	set(value):
		profile = value
		apply_profile()
			

@export var mesh: MeshInstance3D

func _ready():
	apply_profile()
	
func apply_profile():
	print("Apply profile")
	if profile == null:
		return

	_apply_mesh()
	_apply_material()
	
func _apply_mesh():
	var quad := mesh.mesh as QuadMesh
	if quad == null:
		return

	quad.size = Vector2(profile.width, profile.length)

	mesh.position.y = profile.length * 0.5
	
	
func _apply_material():
	var material := mesh.material_override as ShaderMaterial
	if material == null:
		return

	material.set_shader_parameter("trail_color", profile.color)
	material.set_shader_parameter("tail_width", profile.tail_width)
	material.set_shader_parameter("core_size", profile.core_size)
	material.set_shader_parameter("glow_size", profile.glow_size)
	material.set_shader_parameter("emission_strength", profile.emission_strength)
