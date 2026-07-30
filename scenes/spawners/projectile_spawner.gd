extends Node
class_name Projectile_spawner

@export var world: World

func spawn(weapon: WeaponData, spawn_transform: Transform3D):
	var projectile := weapon.projectile_scene.instantiate() as Projectile
	world.projectiles.add_child(projectile)

	projectile.global_transform = spawn_transform
	projectile.initialize(weapon)
