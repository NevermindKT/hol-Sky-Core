@tool
extends Node3D

@export var data: BulletTrailData:
	set(value):
		data = value
		apply_data()
			

@export var mesh: MeshInstance3D

func _ready():
	apply_data()
	
func apply_data():
	print("Apply profile")
	if data == null:
		return

	_apply_mesh()
	_apply_material()
	
func _apply_mesh():
	var quad := mesh.mesh as QuadMesh
	if quad == null:
		return

	quad.size = Vector2(data.width, data.length)

	mesh.position.y = data.length * 0.5
	
	
func _apply_material():
	var material := mesh.material_override as ShaderMaterial
	if material == null:
		return

	material.set_shader_parameter("trail_color", data.color)
	material.set_shader_parameter("tail_width", data.tail_width)
	material.set_shader_parameter("core_size", data.core_size)
	material.set_shader_parameter("glow_size", data.glow_size)
	material.set_shader_parameter("emission_strength", data.emission_strength)
