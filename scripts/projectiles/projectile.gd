extends Node3D
class_name Projectile

var damage: float
var gravity_scale := 1.0
var projectile_speed: float
var projectile_distance: float

const GRAVITY := Vector3.DOWN * 9.81

var velocity: Vector3
var start_position: Vector3

func initialize(data: WeaponData, direction: Vector3):
	start_position = global_position
	
	damage = data.damage
	gravity_scale = data.gravity_scale
	projectile_speed = data.projectile_speed
	projectile_distance = data.projectile_distance
	velocity = direction.normalized() * projectile_speed

func _physics_process(delta):
	velocity += GRAVITY * gravity_scale * delta
	global_position += velocity * delta

	if global_position.distance_to(start_position) >= projectile_distance:
		queue_free()
