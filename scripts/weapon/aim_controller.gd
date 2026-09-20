extends Node
class_name Aim_Controller

var car: Car_Movement
var weapon_pivot: Node3D
var flashlight: SpotLight3D

@export var aim_distance: float
@export var aim_assist_radius: float = 60.0
@export var flashlight_aim_smoothing: float = 15.0

var secondary_reticle_screen_pos: Vector2
var is_locked_on: bool = false

func _ready() -> void:
	weapon_pivot = car.weapon_pivot
	flashlight = weapon_pivot.get_node("AimFlashlight")


func _process(delta: float) -> void:
	var real_transform := car.player_cam.global_transform
	car.player_cam.global_transform = car.player_cam.get_aim_transform()

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

	weapon_pivot.look_at(target)

	var flashlight_desired_basis := Transform3D(Basis(), flashlight.global_position).looking_at(target, Vector3.UP).basis
	var flashlight_smoothing := 1.0 - exp(-flashlight_aim_smoothing * delta)
	flashlight.global_basis = flashlight.global_basis.slerp(flashlight_desired_basis, flashlight_smoothing)

	car.player_cam.global_transform = real_transform
