extends Node3D
class_name Encounter_Enemy


enum State {
	FOLLOW,
	DASH
}

@export_category("Health")

@export var max_health := 100.0

var health: float

@export_category("Movement")

@export var move_speed := 5.0
@export var desired_offset := 0.0


@export_category("Attack")

@export var attack_damage := 15.0
@export var attack_delay := 2.0


@export_category("Dash")

@export var dash_speed := 30.0
@export var dash_duration := 1.0

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
	health = max_health
	damage_hit_box.body_entered.connect(_on_attack_area_body_entered)
	damage_hit_box.damaged.connect(take_damage)


func initialize(target_player: Node3D, target_encounter: Enemy_Encounter) -> void:
	player = target_player
	encounter = target_encounter
	start_z = position.z


func activate() -> void:
	is_active = true
	attack_timer = attack_delay


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
	var target_x := player.global_position.x + desired_offset

	global_position.x = move_toward(
		global_position.x,
		target_x,
		move_speed * delta
	)


func update_attack(delta: float) -> void:
	attack_timer -= delta

	if attack_timer > 0.0:
		return

	start_dash()


func start_dash() -> void:
	state = State.DASH
	dash_timer = dash_duration

	dash_direction = (player.global_position - global_position).normalized()


func update_dash(delta: float) -> void:
	dash_timer -= delta
	global_position += dash_direction * dash_speed * delta

	if dash_timer <= 0.0:
		end_dash()


func end_dash() -> void:
	reset_position()
	
	state = State.FOLLOW
	attack_timer = attack_delay


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
	Events.player_take_damage.emit(attack_damage)
	end_dash()


func take_damage(damage: float) -> void:
	health -= damage
	
	print("Enemy health: ", health)
	
	if health <= 0.0:
		die()


func die() -> void:
	queue_free()
