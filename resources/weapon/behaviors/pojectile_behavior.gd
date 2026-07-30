extends Fire_behavior
class_name Projectile_behavior

func fire(controller: Weapon_controller):
	controller.spawner.spawn(
		controller.current_weapon,
		controller.fire_point.global_transform
	)
