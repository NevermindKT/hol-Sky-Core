
extends Node3D
class_name Tank_Boss

signal health_changed(current: float, maximum: float)

@export_category("Health")
@export var max_health: float = 5000.0

@export_category("Movement")
@export var z_return_speed: float = 3.0

@export_category("Turret")
@export var turret_rotation_speed: float = 1.5

var health: float
@export var player: Car_Movement
@export var encounter: Enemy_Encounter

var start_z: float
var is_active := false
var is_dead := false

@export var turret: Node3D


func _ready() -> void:
	health = max_health


func initialize(target_player: Node3D, target_encounter: Enemy_Encounter) -> void:
	player = target_player
	encounter = target_encounter

	var local_position := encounter.to_local(global_position)
	start_z = local_position.z


func activate() -> void:
	is_active = true


func _physics_process(delta: float) -> void:
	if not is_active or is_dead:
		return

	if not is_instance_valid(player):
		return

	update_movement(delta)
	update_turret_aim(delta)


func update_movement(delta: float) -> void:
	var local_position := encounter.to_local(global_position)
	local_position.z = move_toward(
		local_position.z,
		start_z,
		z_return_speed * delta
	)

	global_position = encounter.to_global(local_position)


func update_turret_aim(delta: float) -> void:
	var direction := player.global_position - turret.global_position

	direction.y = 0.0

	if direction.length_squared() < 0.001:
		return

	var target_angle := atan2(-direction.x, -direction.z)

	turret.global_rotation.y = rotate_toward(
		turret.global_rotation.y,
		target_angle,
		turret_rotation_speed * delta
	)


func take_damage(damage: float) -> void:
	if is_dead:
		return

	health = maxf(0.0, health - damage)
	health_changed.emit(health, max_health)

	if health <= 0.0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_active = false
