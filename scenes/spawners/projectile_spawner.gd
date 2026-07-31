extends Node
class_name Projectile_spawner

@export var world: World

func spawn_single(
	weapon: WeaponData,
	spawn_transform: Transform3D
):
	var projectile = weapon.projectile_scene.instantiate()

	world.projectiles.add_child(projectile)

	projectile.global_transform = spawn_transform

	projectile.initialize(
		weapon,
		-spawn_transform.basis.z
	)


func spawn_projectile(
	weapon: WeaponData,
	position: Vector3,
	direction: Vector3
):

	var projectile = weapon.projectile_scene.instantiate() as Projectile

	world.projectiles.add_child(projectile)

	projectile.global_position = position
	projectile.initialize(
		weapon,
		direction
	)


func spawn_multiple(
	weapon: WeaponData,
	spawn_transform: Transform3D
):

	for i in weapon.projectile_count:

		var direction = get_spread_direction(
			spawn_transform,
			weapon.spread_angle
		)

		spawn_projectile(
			weapon,
			spawn_transform.origin,
			direction
		)


func get_spread_direction(
	transform: Transform3D,
	angle: float
) -> Vector3:

	var direction = -transform.basis.z

	var right = transform.basis.x
	var up = transform.basis.y

	var yaw = deg_to_rad(randf_range(-angle, angle))
	var pitch = deg_to_rad(randf_range(-angle, angle))

	direction = direction.rotated(up, yaw)
	direction = direction.rotated(right, pitch)

	return direction.normalized()
