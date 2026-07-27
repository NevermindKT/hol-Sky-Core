extends Fire_behavior
class_name Projectile_behavior

func fire(controller):
	var projectile = controller.current_weapon.projectile_scene.instantiate()
	
	projectile.global_transform = controller.fire_point.global_transform	
	controller.get_tree().current_scene.add_child(projectile)
