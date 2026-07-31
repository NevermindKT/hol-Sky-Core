extends Fire_behavior
class_name Single_projectile_behavior

func fire(controller: Weapon_controller):
	controller.spawner.spawn_single(
		controller.current_weapon,
		controller.fire_point.global_transform
	)
