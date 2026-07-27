extends Node3D
class_name Projectile

var damage: float
var projectile_speed: float
var projectile_distance: float

var start_position: Vector3

func initialize(data: WeaponData):
	start_position = global_position
	
	damage = data.damage
	projectile_speed = data.projectile_speed
	projectile_distance = data.projectile_distance

func _physics_process(delta):
	global_position += -global_basis.z * projectile_speed * delta

	if global_position.distance_to(start_position) >= projectile_distance:
		queue_free()
