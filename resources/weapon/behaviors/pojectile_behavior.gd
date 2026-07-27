extends Fire_behavior
class_name Projectile_behavior

func fire(controller: Weapon_controller):
	var projectile = controller.current_weapon.projectile_scene.instantiate()
	
	controller.world.projectiles.add_child(projectile)
	
	projectile.global_transform = controller.fire_point.global_transform
	projectile.initialize(controller.current_weapon)
	
	print("Attemted to fire...")
