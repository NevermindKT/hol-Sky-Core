extends Node3D
class_name Enemy_Encounter

@export_category("Group Spawning")
@export var enemy_pool: Array[EncounterEnemyData] = []
@export var enemies_max_weight: float = 100.0


@export_category("Formation")
@export var formation_spacing := 3.0

@export_category("Spawn")
@export var offscreen_spawn_distance := 12.0
@export var offscreen_spawn_spacing := 3.0

@export_category("Attack Queue")
@export var attack_cooldown := 1.0

var attack_cooldown_timer := 0.0


@export_category("Exports")
var player: Node3D
@export var test_Enemy: EncounterEnemyData

var world: World

var is_battle := false

var current_weight: float = 0.0
var enemies: Array[Encounter_Enemy] = []

var attacker: Encounter_Enemy = null


func _ready() -> void:
	process_physics_priority = 10
	Events.player_hard_brake.connect(_on_player_hard_brake)

func inialize(_world: World) -> void:
	world = _world

	if !get_children():
		print("There no initial enemys in enemy encounter!")

	for child in get_children():
		if child is Encounter_Enemy:
			enemies.append(child)

			child.initialize(player, self, child.enemy_data)

	_reflow_formation()


func _process(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta


func _physics_process(_delta: float) -> void:
	if enemies.size() < 2:
		return

	var list := enemies.duplicate()

	for i in list.size():
		for j in range(i + 1, list.size()):
			var a: Encounter_Enemy = list[i]
			var b: Encounter_Enemy = list[j]

			if a.is_queued_for_deletion() or b.is_queued_for_deletion():
				continue
			if not a.is_active or not b.is_active:
				continue

			_resolve_pair(a, b)


func _resolve_pair(a: Encounter_Enemy, b: Encounter_Enemy) -> void:
	var offset := b.global_position - a.global_position
	offset.y = 0.0

	var min_distance := a.enemy_data.body_radius + b.enemy_data.body_radius
	var distance := offset.length()

	if distance >= min_distance:
		return

	_try_knockback_hit(a, b)
	_try_knockback_hit(b, a)

	if a.is_queued_for_deletion() or b.is_queued_for_deletion():
		return

	var direction := offset / distance if distance > 0.001 else Vector3.RIGHT
	var overlap := min_distance - distance

	# Кто не в FOLLOW (летит, оглушён, атакует) — "якорь": его не сдвигаем, уступает второй
	var a_anchored := a.state != Encounter_Enemy.State.FOLLOW
	var b_anchored := b.state != Encounter_Enemy.State.FOLLOW

	var a_share := 0.5
	if a_anchored and not b_anchored:
		a_share = 0.0
	elif b_anchored and not a_anchored:
		a_share = 1.0

	a.global_position -= direction * overlap * a_share
	b.global_position += direction * overlap * (1.0 - a_share)


func _try_knockback_hit(source: Encounter_Enemy, target: Encounter_Enemy) -> void:
	if source.state != Encounter_Enemy.State.KNOCKBACK:
		return
	if source.knockback_velocity.length() < source.enemy_data.knockback_hit_min_speed:
		return
	if target in source.knockback_hit_targets:
		return

	source.knockback_hit_targets.append(target)
	target.take_collision_damage(source.enemy_data.knockback_collision_damage)

# ============================ SPAWN ===========================================

func spawn_random_group() -> void:
	if enemy_pool.is_empty():
		push_warning("Enemy_Encounter: enemy_pool is empty!")
		return

	var new_enemies: Array = []
	var attempts := 0
	var max_attempts := 50

	while attempts < max_attempts:
		attempts += 1

		var remaining := enemies_max_weight - current_weight
		var candidates := enemy_pool.filter(func(data): return data.weight <= remaining)

		if candidates.is_empty():
			break

		var chosen: EncounterEnemyData = candidates[randi() % candidates.size()]
		var enemy := add_enemy(chosen, false)
		if enemy:
			new_enemies.append(enemy)

	_spawn_offscreen_batch(new_enemies)
	start_encounter()


func add_enemy(enemy_data: EncounterEnemyData, spawn_offscreen := true) -> Encounter_Enemy:
	if enemy_data == null:
		push_warning("Enemy_Encounter: enemy_data is null!")
		return null
	
	if enemy_data.enemy_scene == null:
		push_error("Enemy_Encounter: enemy_scene is null!")
		return null
	
	var enemy := enemy_data.enemy_scene.instantiate() as Encounter_Enemy
	
	if enemy == null:
		push_error(
			"Enemy_Encounter: enemy_scene does not have Encounter_Enemy script!"
		)
		return null
	
	add_child(enemy)
	enemies.append(enemy)
	current_weight += enemy_data.weight
	
	enemy.initialize(player, self, enemy_data)
	_reflow_formation()
	
	if spawn_offscreen:
		_spawn_offscreen_batch([enemy])

	is_battle = true
	return enemy


func _spawn_offscreen_batch(batch: Array) -> void:
	var left: Array = []
	var right: Array = []

	for enemy in batch:
		var side := signf(enemy.formation_offset)
		if side == 0.0:
			side = 1.0 if right.size() <= left.size() else -1.0

		if side > 0.0:
			right.append(enemy)
		else:
			left.append(enemy)

	_place_side(left, -1.0)
	_place_side(right, 1.0)


func _place_side(side_enemies: Array, side: float) -> void:
	side_enemies.sort_custom(func(a, b): return absf(a.formation_offset) < absf(b.formation_offset))

	for i in side_enemies.size():
		var distance := offscreen_spawn_distance + i * offscreen_spawn_spacing
		side_enemies[i].global_position.x = player.global_position.x + side * distance


func remove_enemy(enemy: Encounter_Enemy) -> void:
	enemies.erase(enemy)
	current_weight = max(0.0, current_weight - enemy.enemy_data.weight)
	_reflow_formation()
	check_battle()


func _reflow_formation() -> void:
	var n := enemies.size()
	if n == 0:
		return
	
	for i in range(n):
		var slot_index := i - (n - 1) / 2.0
		enemies[i].set_formation_offset(slot_index * formation_spacing)

# ============================ ENCOUNTER STATUS ================================

func start_encounter() -> void:
	for enemy in enemies:
		enemy.activate()
	check_battle()


func check_battle() -> void:
	is_battle = is_there_enemies()


func is_there_enemies() -> bool:
	return not enemies.is_empty()

# ============================ ENEMY MANAGE ====================================

func try_start_attack(enemy: Encounter_Enemy) -> bool:
	if attacker != null and attacker != enemy:
		return false
	if attacker == null and attack_cooldown_timer > 0.0:
		return false
	
	attacker = enemy
	return true


func end_attak(enemy: Encounter_Enemy) -> void:
	if attacker == enemy:
		attacker = null
		attack_cooldown_timer = attack_cooldown


func _on_player_hard_brake(force: float) -> void:
	var forward := -player.global_transform.basis.z
	
	for enemy in enemies:
		enemy.apply_inertia_impulse(forward * force)

# ============================ DEBUG ===========================================

func add_test_enemy() -> void:
	add_enemy(test_Enemy)
	start_encounter()
