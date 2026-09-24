extends Node
class_name Grenade_spawner

const FLASHBANG_SCENE := preload("res://scenes/projectiles/flashbang_grenade.tscn")
const ARC_VERTICAL_SPEED := 8.0
const THROW_SPREAD_DEGREES := 8.0

var car: Car_Movement
var enemy_encounter: Enemy_Encounter

func spawn_flashbang() -> void:
	var launch_point := car.visual_effects.get_node("GrenadeLaunchPoint") as Node3D
	var grenade := FLASHBANG_SCENE.instantiate() as FlashbangGrenade
	var anchor := car.get_parent() as Node3D

	anchor.add_child(grenade)
	grenade.transform = anchor.global_transform.affine_inverse() * launch_point.global_transform

	var direction := get_spread_direction(grenade.transform)
	grenade.velocity = direction * grenade.throw_speed + Vector3.UP * ARC_VERTICAL_SPEED

	grenade.detonated.connect(_stun_all_enemies)


func _stun_all_enemies() -> void:
	for enemy in enemy_encounter.enemies:
		enemy.add_stun(enemy.enemy_data.stun_treshold)


func get_spread_direction(from_transform: Transform3D) -> Vector3:
	var direction := -from_transform.basis.z
	var right := from_transform.basis.x
	var up := from_transform.basis.y

	var yaw := deg_to_rad(randf_range(-THROW_SPREAD_DEGREES, THROW_SPREAD_DEGREES))
	var pitch := deg_to_rad(randf_range(-THROW_SPREAD_DEGREES, THROW_SPREAD_DEGREES))

	direction = direction.rotated(up, yaw)
	direction = direction.rotated(right, pitch)

	return direction.normalized()
