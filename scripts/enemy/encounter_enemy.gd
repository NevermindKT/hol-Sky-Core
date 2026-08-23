extends Node3D
class_name Encounter_Enemy


enum State {
	FOLLOW,
	DASH
}


@export_category("Movement")

@export var move_speed := 5.0
@export var desired_offset := 0.0


@export_category("Attack")

@export var attack_delay := 2.0


@export_category("Dash")

@export var dash_speed := 30.0
@export var dash_duration := 1.0


var player: Node3D

var state := State.FOLLOW

var attack_timer := 0.0

var dash_timer := 0.0
var dash_direction := Vector3.ZERO

var is_active := false


@onready var damage_hit_box: Area3D = $DamageHitBox


func _ready() -> void:
	damage_hit_box.body_entered.connect(
		_on_attack_area_body_entered
	)


func initialize(target_player: Node3D) -> void:
	player = target_player


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

	dash_direction = (
		player.global_position - global_position
	).normalized()


func update_dash(delta: float) -> void:
	dash_timer -= delta

	global_position += dash_direction * dash_speed * delta

	if dash_timer <= 0.0:
		end_dash()


func end_dash() -> void:
	state = State.FOLLOW

	attack_timer = attack_delay


func _on_attack_area_body_entered(body: Node3D) -> void:
	if state != State.DASH:
		return

	if body != player:
		return

	hit_player()


func hit_player() -> void:
	print("PLAYER HIT")

	end_dash()
