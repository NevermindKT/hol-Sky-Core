extends Node3D
class_name Encounter_Enemy

enum State {
	FOLLOW,
	DASH,
	KNOCKBACK
}

signal attack_state_changed(is_warning: bool)

@export var enemy_data: EncounterEnemyData

var health: float
var is_active := false

var player: Node3D
var encounter: Enemy_Encounter

var start_z: float
var attack_timer := 0.0
var state := State.FOLLOW

var dash_timer := 0.0
var is_warning := false
var dash_direction := Vector3.ZERO

var knockback_drag := 8.0
var knockback_velocity := Vector3.ZERO

@onready var damage_hit_box: HurtBox = $DamageHitBox


func _ready() -> void:
	damage_hit_box.body_entered.connect(_on_attack_area_body_entered)
	damage_hit_box.hit.connect(_on_hit)


func initialize(target_player: Node3D, target_encounter: Enemy_Encounter, data: EncounterEnemyData) -> void:
	enemy_data = data
	player = target_player
	encounter = target_encounter
	health = enemy_data.max_health
	start_z = position.z


func activate() -> void:
	is_active = true
	attack_timer = enemy_data.attack_delay
	_set_warning(false)


func _physics_process(delta: float) -> void:
	if not is_active:
		return
	if player == null:
		return
	match state:
		State.FOLLOW:
			update_movement(delta)
			update_attack(delta)
		State.DASH:
			update_dash(delta)
		State.KNOCKBACK:
			update_knockback(delta)


func update_movement(delta: float) -> void:
	var target_x := player.global_position.x + enemy_data.desired_offset
	global_position.x = move_toward(
		global_position.x,
		target_x,
		enemy_data.move_speed * delta
	)


func update_attack(delta: float) -> void:
	attack_timer -= delta
	
	if not is_warning and attack_timer <= enemy_data.attack_warning_time:
		_set_warning(true)
	
	if attack_timer > 0.0:
		return
	start_dash()


func update_knockback(delta: float) -> void:
	global_position += knockback_velocity * delta
	knockback_velocity *= exp(-knockback_drag * delta)
	
	if knockback_velocity.length() < 0.2:
		state = State.FOLLOW
		attack_timer = enemy_data.attack_delay


func update_dash(delta: float) -> void:
	dash_timer -= delta
	global_position += dash_direction * enemy_data.dash_speed * delta
	if dash_timer <= 0.0:
		end_dash()


func start_dash() -> void:
	_set_warning(false)
	state = State.DASH
	dash_timer = enemy_data.dash_duration
	dash_direction = (player.global_position - global_position).normalized()


func end_dash() -> void:
	reset_position()
	state = State.FOLLOW
	attack_timer = enemy_data.attack_delay


func reset_position() -> void:
	var local_position := encounter.to_local(global_position)
	local_position.z = start_z
	global_position = encounter.to_global(local_position)


func _set_warning(value: bool) -> void:
	if is_warning == value:
		return
	is_warning = value
	attack_state_changed.emit(is_warning)


func _on_attack_area_body_entered(body: Node3D) -> void:
	if state != State.DASH:
		return
	if body != player:
		return
	hit_player()


func on_dodge_hit(damage: float, knockback: Vector3) -> void:
	take_damage(damage)
	if health <= 0.0:
		return
	
	_set_warning(false)
	state = State.KNOCKBACK
	knockback_velocity = knockback


func _on_hit(hit_position: Vector3, direction: Vector3, damage: float) -> void:
	take_damage(damage)
	_spawn_hit_effect(hit_position, direction)


func hit_player() -> void:
	print("PLAYER HIT")
	Events.player_take_damage.emit(enemy_data.attack_damage)
	end_dash()


func take_damage(damage: float) -> void:
	health -= damage
	print("Enemy health: ", health)
	if health <= 0.0:
		die()


func _spawn_hit_effect(hit_position: Vector3, direction: Vector3) -> void:
	var effect := enemy_data.hit_effect_scene.instantiate() as BloodCarHit
	get_parent().world.enemies.add_child(effect)
	effect.play(hit_position, direction)


func die() -> void:
	_set_warning(false)
	encounter.remove_enemy(self)
	print("Call encounter to remove enemy")
	queue_free()
