extends Fire_behavior
class_name Multiple_projectile_behavior


func fire(controller: Weapon_controller):
	ProjectileSpawner.spawn_multiple(
		controller.current_weapon.data,
		controller.fire_point.global_transform
	)
