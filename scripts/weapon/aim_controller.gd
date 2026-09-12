extends Node
class_name Aim_Controller

var car: Car_Movement
var weapon_pivot: Node3D

@export var aim_distance: float
@export var aim_assist_radius: float = 60.0

var secondary_reticle_screen_pos: Vector2
var is_locked_on: bool = false

func _ready() -> void:
	weapon_pivot = car.weapon_pivot


func _process(_delta: float) -> void:
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

	weapon_pivot.look_at(target)
