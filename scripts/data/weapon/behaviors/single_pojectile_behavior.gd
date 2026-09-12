extends Fire_behavior
class_name Single_projectile_behavior

func fire(controller: Weapon_controller):
	var spawn_transform := controller.fire_point.global_transform
	spawn_transform.basis = _apply_spread(spawn_transform.basis, controller.current_spread)
	
	ProjectileSpawner.spawn_single(
		controller.current_weapon.data,
		spawn_transform
	)

func _apply_spread(basis: Basis, spread_radians: float) -> Basis:
	if spread_radians <= 0.0:
		return basis
	
	var yaw := randf_range(-spread_radians, spread_radians)
	var pitch := randf_range(-spread_radians, spread_radians)
	
	return basis.rotated(basis.y, yaw).rotated(basis.x, pitch)
