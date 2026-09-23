extends Node
class_name Aim_Controller

var car: Car_Movement
var weapon_pivot: GunMove   # теперь это узел со скриптом GunMove

@export var aim_distance: float
@export var aim_assist_radius: float = 60.0
@export var yaw_speed: float = 3.0   # скорость поворота турели по горизонтали, рад/с

var secondary_reticle_screen_pos: Vector2
var is_locked_on: bool = false


func _ready() -> void:
	weapon_pivot = car.gun


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
		var collider = result.collider
		if collider is HurtBox:
			target = result.position
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
	# --- горизонтальный поворот всей турели (yaw), с ограничением скорости ---
	var to_target := target - weapon_pivot.global_position
	var flat := Vector3(to_target.x, 0.0, to_target.z)

	if flat.length_squared() > 0.0001:
		var desired_yaw := atan2(flat.x, flat.z)
		weapon_pivot.rotation.y = _rotate_angle_toward(weapon_pivot.rotation.y, desired_yaw, yaw_speed * delta)

	# --- вертикальный поворот ствола (pitch) — считается уже в локальных координатах турели ---
	var local_target := weapon_pivot.to_local(target)
	weapon_pivot.aim_pitch(local_target, delta)


## Поворот угла к цели с ограничением максимального шага за кадр,
## корректно обрабатывает переход через ±180°
func _rotate_angle_toward(from: float, to: float, max_delta: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	if abs(diff) <= max_delta:
		return from + diff
	return from + sign(diff) * max_delta
