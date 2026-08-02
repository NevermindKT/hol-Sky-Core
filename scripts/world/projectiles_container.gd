extends Node3D
class_name Projectile_container

@onready var world: World = $".."

func _process(_delta):
	var current_basis = world.world.global_transform.basis
	var delta_rotation = current_basis * world.last_world_basis.inverse()

	global_rotation = world.world.global_rotation

	for p in self.get_children():
		if p is Projectile:
			p.velocity = delta_rotation * p.velocity

	world.last_world_basis = current_basis
