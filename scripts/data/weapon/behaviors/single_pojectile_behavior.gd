extends Fire_behavior
class_name Single_projectile_behavior

func fire(controller: Weapon_controller):
	ProjectileSpawner.spawn_single(
		controller.current_weapon.data,
		controller.fire_point.global_transform
	)
