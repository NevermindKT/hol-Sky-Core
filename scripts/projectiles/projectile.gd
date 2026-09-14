extends Node3D
class_name Projectile


var damage: float
var gravity_scale := 1.0
var projectile_speed: float
var projectile_distance: float

const GRAVITY := Vector3.DOWN * 9.81

var velocity: Vector3
var start_position: Vector3

var bounces_left := 0
var hit_enemies: Array[Encounter_Enemy] = []


func initialize(data: WeaponData, direction: Vector3) -> void:
	start_position = global_position

	damage = UpgradeManager.get_modified(&"weapon_damage", data.damage)
	gravity_scale = data.gravity_scale
	projectile_speed = data.projectile_speed
	projectile_distance = data.projectile_distance
	bounces_left = int(UpgradeManager.get_modified(&"bullet_ricochet", 0.0))

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
		global_position = hit.position

		collider.receive_hit(
			hit.position,
			velocity.normalized(),
			damage
		)

		var enemy := collider.get_parent() as Encounter_Enemy

		if enemy:
			hit_enemies.append(enemy)

			if bounces_left > 0 and _try_ricochet(enemy):
				return

	queue_free()


func _try_ricochet(enemy: Encounter_Enemy) -> bool:
	var candidates := enemy.encounter.enemies.filter(func(e): return not hit_enemies.has(e))

	if candidates.is_empty():
		return false

	var target: Encounter_Enemy = candidates[randi() % candidates.size()]

	bounces_left -= 1
	start_position = global_position
	velocity = (target.global_position - global_position).normalized() * projectile_speed

	look_at(target.global_position, Vector3.UP)

	return true
