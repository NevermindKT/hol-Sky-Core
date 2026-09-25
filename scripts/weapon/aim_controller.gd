extends Node
class_name Aim_Controller

var car: Car_Movement
var gun: GunMove

@export var aim_distance: float
@export var aim_assist_radius: float = 60.0
@export var yaw_speed: float = 2.0

var secondary_reticle_screen_pos: Vector2
var is_locked_on: bool = false


func _ready() -> void:	
	gun = car.gun


func _process(delta: float) -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := car.player_cam.project_ray_origin(mouse_pos)
	var direction := car.player_cam.project_ray_normal(mouse_pos)
	var target := origin + direction * aim_distance

	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * aim_distance
	)

	query.collide_with_areas = true
	var space_state := car.get_world_3d().direct_space_state
	var result := space_state.intersect_ray(query)

	var direct_hit := false
	if not result.is_empty():
		target = result.position

		if result.collider is HurtBox:
			direct_hit = true

	if not direct_hit:
		var best_hurtbox: HurtBox = null
		var best_dist := aim_assist_radius

		for hb in get_tree().get_nodes_in_group("hurtboxes"):
			if car.player_cam.is_position_behind(hb.global_position):
				continue
			var screen_pos := car.player_cam.unproject_position(hb.global_position)
			var dist := mouse_pos.distance_to(screen_pos)
			if dist < best_dist:
				best_dist = dist
				best_hurtbox = hb

		if best_hurtbox:
			target = best_hurtbox.global_position
			direct_hit = true

	is_locked_on = direct_hit
	secondary_reticle_screen_pos = car.player_cam.unproject_position(target) if is_locked_on else mouse_pos

	_aim_turret(target, delta)


func _aim_turret(target: Vector3, delta: float) -> void:
	var to_target := target - gun.global_position
	var flat := Vector3(to_target.x, 0.0, to_target.z)

	if flat.length_squared() > 0.0001:
		var desired_yaw := atan2(flat.x, flat.z)
		gun.rotation.y = _rotate_angle_toward(gun.rotation.y, desired_yaw, yaw_speed * delta)

	var local_target := gun.to_local(target)
	gun.aim_pitch(local_target, delta)


func _rotate_angle_toward(from: float, to: float, max_delta: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	if abs(diff) <= max_delta:
		return from + diff
	return from + sign(diff) * max_delta
