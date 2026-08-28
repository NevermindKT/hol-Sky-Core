extends Node3D
class_name Encounter_Enemy


enum State {
	FOLLOW,
	DASH
}

@export var enemy_data: EncounterEnemyData

var health: float

var is_active := false

var player: Node3D
var encounter: Enemy_Encounter

var start_z: float
var attack_timer := 0.0
var state := State.FOLLOW

var dash_timer := 0.0
var dash_direction := Vector3.ZERO

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


func update_movement(delta: float) -> void:
	var target_x := player.global_position.x + enemy_data.desired_offset

	global_position.x = move_toward(
		global_position.x,
		target_x,
		enemy_data.move_speed * delta
	)


func update_attack(delta: float) -> void:
	attack_timer -= delta

	if attack_timer > 0.0:
		return

	start_dash()


func start_dash() -> void:
	state = State.DASH
	dash_timer = enemy_data.dash_duration

	dash_direction = (player.global_position - global_position).normalized()


func update_dash(delta: float) -> void:
	dash_timer -= delta
	global_position += dash_direction * enemy_data.dash_speed * delta

	if dash_timer <= 0.0:
		end_dash()


func end_dash() -> void:
	reset_position()
	
	state = State.FOLLOW
	attack_timer = enemy_data.attack_delay


func reset_position() -> void:
	var local_position := encounter.to_local(global_position)

	local_position.z = start_z
	global_position = encounter.to_global(local_position)


func _on_attack_area_body_entered(body: Node3D) -> void:
	if state != State.DASH:
		return
	if body != player:
		return

	hit_player()


func hit_player() -> void:
	print("PLAYER HIT")
	Events.player_take_damage.emit(enemy_data.attack_damage)
	end_dash()


func take_damage(damage: float) -> void:
	health -= damage
	
	print("Enemy health: ", health)
	
	if health <= 0.0:
		die()


func _on_hit(hit_position: Vector3, direction: Vector3, damage: float) -> void:
	take_damage(damage)

	_spawn_hit_effect(
		hit_position,
		direction
	)


func _spawn_hit_effect(
	hit_position: Vector3,
	direction: Vector3
) -> void:
	var effect := enemy_data.hit_effect_scene.instantiate() as BloodCarHit

	get_parent().world.enemies.add_child(effect)

	effect.play(
		hit_position,
		direction
	)


func die() -> void:
	encounter.remove_enemy(self)
	print("Call encounter to remove enemy")
	queue_free()
