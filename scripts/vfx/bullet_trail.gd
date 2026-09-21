@tool
extends Node3D
class_name BulletTrail

@export var data: BulletTrailData:
	set(value):
		data = value
		apply_data()


@export var mesh: MeshInstance3D

const CONTINUITY_MARGIN := 1.5

func _ready():
	apply_data()


func _physics_process(_delta: float) -> void:
	var projectile := get_parent() as Projectile
	if projectile:
		sync_to_projectile(projectile)


func sync_to_projectile(projectile: Projectile) -> void:
	align_to_velocity(projectile.velocity)

	var continuity_length := projectile.velocity.length() * get_physics_process_delta_time() * CONTINUITY_MARGIN
	var distance_traveled := projectile.global_position.distance_to(projectile.start_position)

	_update_length(distance_traveled, continuity_length)


func align_to_velocity(velocity: Vector3) -> void:
	if velocity.length_squared() < 0.0001:
		return

	var backward := -velocity.normalized()
	var reference := Vector3.UP if abs(backward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var side := reference.cross(backward).normalized()
	var up := side.cross(backward)

	global_transform = Transform3D(Basis(side, backward, up), global_position)


func apply_data():
	if data == null:
		return

	_apply_mesh()
	_apply_material()

func _apply_mesh():
	var cylinder := mesh.mesh as CylinderMesh
	if cylinder == null:
		return

	cylinder.top_radius = data.width
	cylinder.bottom_radius = data.width
	cylinder.height = data.length

	mesh.position.y = data.length * 0.5


func _update_length(distance_traveled: float, continuity_length: float) -> void:
	if data == null:
		return

	var cylinder := mesh.mesh as CylinderMesh
	if cylinder == null:
		return

	var target_length: float = max(data.length, continuity_length)
	var visible_length: float = min(target_length, distance_traveled)

	cylinder.height = visible_length
	mesh.position.y = visible_length * 0.5


func _apply_material():
	var material := mesh.material_override as ShaderMaterial
	if material == null:
		return

	material.set_shader_parameter("trail_color", data.color)
	material.set_shader_parameter("tail_width", data.tail_width)
	material.set_shader_parameter("core_size", data.core_size)
	material.set_shader_parameter("glow_size", data.glow_size)
	material.set_shader_parameter("emission_strength", data.emission_strength)
