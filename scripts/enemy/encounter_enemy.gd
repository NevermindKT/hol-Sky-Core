extends Node3D
class_name Encounter_Enemy

enum State {
	FOLLOW,
	DASH,
	KNOCKBACK,
	STUNNED
}

@export var enemy_data: EncounterEnemyData
@export var thermal_material: StandardMaterial3D

var health: float
var is_active := false
var formation_offset: float = 0.0

signal attack_state_changed(is_warning: bool)
signal stun_state_changed(is_stunned: bool)

var stun_meter: float = 0.0
var stun_timer := 0.0
var is_stunned := false

const HIT_SLOW_DURATION := 2.0
var slow_timer := 0.0

var poison_timer := 0.0
var poison_dps := 0.0

var player: Node3D
var encounter: Enemy_Encounter

var start_z: float
var attack_timer := 0.0
var state := State.FOLLOW

var dash_distance_left := 0.0
var is_warning := false
var dash_direction := Vector3.ZERO

var knockback_drag := 8.0
var knockback_velocity := Vector3.ZERO

var _speed_multiplier := 1.0

@onready var damage_hit_box: HurtBox = $DamageHitBox
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	damage_hit_box.body_entered.connect(_on_attack_area_body_entered)
	damage_hit_box.hit.connect(_on_hit)

	Events.thermal_vision_changed.connect(_on_thermal_vision_changed)
	_on_thermal_vision_changed(Events.thermal_vision_active)


func _on_thermal_vision_changed(active: bool) -> void:
	mesh_instance.material_override = thermal_material if active else null


func initialize(target_player: Node3D, target_encounter: Enemy_Encounter, data: EncounterEnemyData) -> void:
	enemy_data = data
	player = target_player
	encounter = target_encounter
	health = enemy_data.max_health
	start_z = position.z
	formation_offset = enemy_data.desired_offset


func activate() -> void:
	is_active = true
	attack_timer = enemy_data.attack_delay
	_set_warning(false)


func _physics_process(delta: float) -> void:
	_speed_multiplier = _current_speed_multiplier()
	
	if not is_active:
		return
	if player == null:
		return
	
	if state != State.STUNNED:
		decay_stun(delta)

	if slow_timer > 0.0:
		slow_timer = max(0.0, slow_timer - delta)

	if poison_timer > 0.0:
		update_poison(delta)

	match state:
		State.FOLLOW:
			update_movement(delta)
			update_attack(delta)
		State.DASH:
			update_dash(delta)
		State.KNOCKBACK:
			update_knockback(delta)
		State.STUNNED:
			update_stun(delta)

# ============================ STATE UPDATES ===================================

func update_movement(delta: float) -> void:

	var target_x := player.global_position.x + formation_offset
	global_position.x = move_toward(
		global_position.x,
		target_x,
		enemy_data.move_speed * _speed_multiplier * delta
	)

	_move_toward_start_z(delta, _speed_multiplier)


func update_attack(delta: float) -> void:
	attack_timer -= delta

	if not is_warning and attack_timer <= enemy_data.attack_warning_time:
		_set_warning(true)

	if attack_timer > 0.0:
		return

	if encounter.try_start_attack(self):
		start_dash()


func update_knockback(delta: float) -> void:
	global_position += knockback_velocity * delta
	knockback_velocity *= exp(-knockback_drag * delta)
	
	if knockback_velocity.length() < 0.2:
		state = State.FOLLOW
		attack_timer = enemy_data.attack_delay


func update_dash(delta: float) -> void:
	var step := enemy_data.dash_speed * _speed_multiplier * delta
	global_position += dash_direction * step
	dash_distance_left -= step
	if dash_distance_left <= 0.0:
		end_dash()


func update_stun(delta: float) -> void:
	stun_timer -= delta
	
	global_position.z = move_toward(
		global_position.z,
		player.global_position.z,
		enemy_data.z_align_speed * delta
	)
	
	if stun_timer <= 0.0:
		end_stun()

# ============================ STATE SWITCHES & VALUES =========================

func add_stun(amount: float) -> void:
	if state == State.STUNNED:
		return
	
	stun_meter += amount
	
	if stun_meter >= enemy_data.stun_treshold:
		start_stun()


func start_stun() -> void:
	_set_warning(false)
	encounter.end_attak(self)
	state = State.STUNNED
	stun_timer = enemy_data.stun_duration
	stun_meter = 0.0
	knockback_velocity = Vector3.ZERO
	_set_stunned(true)


func end_stun() -> void:
	state = State.FOLLOW
	attack_timer = enemy_data.attack_delay
	_set_stunned(false)


func decay_stun(delta: float) -> void:
	if stun_meter <= 0.0:
		return
	stun_meter = max(0.0, stun_meter - enemy_data.stun_decay_rate * delta)


func apply_hit_slow() -> void:
	slow_timer = HIT_SLOW_DURATION


func _current_speed_multiplier() -> float:
	if slow_timer <= 0.0:
		return 1.0
	return UpgradeManager.get_modified(&"enemy_slowdown", 1.0)


func apply_poison() -> void:
	var dps := UpgradeManager.get_modified(&"poison_damage", 0.0)
	var duration := UpgradeManager.get_modified(&"poison_duration", 0.0)

	if dps <= 0.0 or duration <= 0.0:
		return

	poison_dps = dps
	poison_timer = duration


func update_poison(delta: float) -> void:
	poison_timer = max(0.0, poison_timer - delta)
	take_damage(poison_dps * delta)


func start_dash() -> void:
	_set_warning(false)
	state = State.DASH
	dash_distance_left = enemy_data.dash_speed * enemy_data.dash_duration
	dash_direction = (player.global_position - global_position).normalized()


func end_dash() -> void:
	state = State.FOLLOW
	attack_timer = enemy_data.attack_delay
	encounter.end_attak(self)


func set_formation_offset(offset: float) -> void:
	formation_offset = offset

# ============================ MOVEMENT ========================================

func _move_toward_start_z(delta: float, speed_multiplier: float = 1.0) -> void:
	var target_local := encounter.to_local(global_position)
	target_local.z = start_z
	var target_global_z := encounter.to_global(target_local).z

	global_position.z = move_toward(
		global_position.z,
		target_global_z,
		enemy_data.z_return_speed * speed_multiplier * delta
	)


func reset_position() -> void:
	var local_position := encounter.to_local(global_position)
	local_position.z = start_z
	global_position = encounter.to_global(local_position)

# ============================ SETTERS =========================================

func _set_warning(value: bool) -> void:
	if is_warning == value:
		return
	is_warning = value
	attack_state_changed.emit(is_warning)


func _set_stunned(value: bool) -> void:
	if is_stunned == value:
		return
	is_stunned = value
	stun_state_changed.emit(is_stunned)

# ============================ COLLISION & DAMAGE ==============================

func _on_attack_area_body_entered(body: Node3D) -> void:
	if state != State.DASH:
		return
	if body != player:
		return
	hit_player(body)


func _on_hit(hit_position: Vector3, direction: Vector3, damage: float) -> void:
	take_damage(damage)
	add_stun(UpgradeManager.get_modified(&"enemy_stunning", damage))
	apply_hit_slow()
	apply_poison()

	_spawn_bullet_hit_effect(hit_position, direction)


func on_dodge_hit(damage: float, knockback: Vector3, hit_position: Vector3, direction: Vector3, car: Car_Movement) -> void:
	take_damage(damage)
	if health <= 0.0:
		return

	_set_warning(false)
	_set_stunned(false)
	encounter.end_attak(self)
	_spawn_dodge_hit_effect(hit_position, direction, car)

	state = State.KNOCKBACK
	knockback_velocity = knockback
	stun_meter = 0.0


func hit_player(body: Node3D) -> void:
	print("PLAYER HIT")
	Events.player_take_damage.emit(enemy_data.attack_damage, global_position)

	var car := body as Car_Movement
	if car:
		car.spawn_hit_effect(global_position)

	end_dash()


func take_damage(damage: float) -> void:
	health -= damage
	print("Enemy health: ", health)
	print("Enemy stun: ", stun_meter)

	if health <= 0.0:
		die()
		return


func die() -> void:
	_set_warning(false)
	_set_stunned(false)
	encounter.end_attak(self)
	encounter.remove_enemy(self)
	queue_free()

# ============================ EFFECTS =========================================

func _spawn_bullet_hit_effect(hit_position: Vector3, direction: Vector3) -> void:
	var effect := enemy_data.bullet_hit_effect_scene.instantiate() as BloodBulletHit
	add_child(effect)
	effect.play(hit_position, direction)

func _spawn_dodge_hit_effect(hit_position: Vector3, direction: Vector3, car: Car_Movement) -> void:
	var effect := enemy_data.dodge_hit_effect_scene.instantiate() as BloodCarHit
	get_parent().world.enemies.add_child(effect)
	effect.play(hit_position, direction, car.speed, car)
