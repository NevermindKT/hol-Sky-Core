extends Node3D
class_name Projectile


var damage: float
var gravity_scale := 1.0
var projectile_speed: float
var projectile_distance: float

const GRAVITY := Vector3.DOWN * 9.81

var velocity: Vector3
var start_position: Vector3


func initialize(data: WeaponData, direction: Vector3) -> void:
	start_position = global_position

	damage = UpgradeManager.get_modified(&"weapon_damage", data.damage)
	gravity_scale = data.gravity_scale
	projectile_speed = data.projectile_speed
	projectile_distance = data.projectile_distance

	velocity = direction.normalized() * projectile_speed


func _physics_process(delta: float) -> void:
	velocity += GRAVITY * gravity_scale * delta

	var from := global_position
	var movement := velocity * delta

	var distance_from_start := from.distance_to(start_position)
	var remaining_distance := projectile_distance - distance_from_start

	if remaining_distance <= 0.0:
		queue_free()
		return

	if movement.length() > remaining_distance:
		movement = movement.normalized() * remaining_distance

	var to := from + movement

	var hit := check_collision(from, to)

	if not hit.is_empty():
		handle_hit(hit)
		return

	global_position = to

	if global_position.distance_to(start_position) >= projectile_distance:
		queue_free()


func check_collision(
	from: Vector3,
	to: Vector3
) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		from,
		to
	)

	#query.exclude = [get_rid()]

	query.collide_with_areas = true
	query.collide_with_bodies = false

	return get_world_3d().direct_space_state.intersect_ray(query)


func handle_hit(hit: Dictionary) -> void:
	var collider = hit.collider

	if collider is HurtBox:
		collider.receive_hit(
			hit.position,
			velocity.normalized(),
			damage
		)

	queue_free()
