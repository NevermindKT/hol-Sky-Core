extends Node
class_name Projectile_spawner

var world: World

func spawn_single(
	weapon: WeaponData,
	spawn_transform: Transform3D,
	shooter: CollisionObject3D = null,
	saved: bool = false
):
	var projectile = weapon.projectile_scene.instantiate()

	world.projectiles.add_child(projectile)

	projectile.global_transform = spawn_transform

	projectile.initialize(
		weapon,
		-spawn_transform.basis.z,
		shooter,
		saved
	)


func spawn_projectile(
	weapon: WeaponData,
	position: Vector3,
	direction: Vector3,
	shooter: CollisionObject3D = null,
	saved: bool = false
):

	var projectile = weapon.projectile_scene.instantiate() as Projectile

	world.projectiles.add_child(projectile)

	projectile.global_position = position
	projectile.look_at(position + direction, Vector3.UP)
	projectile.initialize(
		weapon,
		direction,
		shooter,
		saved
	)


func spawn_multiple(
	weapon: WeaponData,
	spawn_transform: Transform3D,
	shooter: CollisionObject3D = null,
	saved: bool = false
):

	for i in weapon.projectile_count:

		var direction = get_spread_direction(
			spawn_transform,
			weapon.spread_angle
		)

		spawn_projectile(
			weapon,
			spawn_transform.origin,
			direction,
			shooter,
			saved
		)


func get_spread_direction(transform: Transform3D, angle: float) -> Vector3:
	var clean_basis := transform.basis.orthonormalized()
	
	var direction = -clean_basis.z

	var right = clean_basis.x
	var up = clean_basis.y

	var yaw = deg_to_rad(randf_range(-angle, angle))
	var pitch = deg_to_rad(randf_range(-angle, angle))

	direction = direction.rotated(up, yaw)
	direction = direction.rotated(right, pitch)

	return direction.normalized()
