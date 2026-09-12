extends Node3D
class_name Enemy_Encounter

@export_category("Group Spawning")
@export var enemy_pool: Array[EncounterEnemyData] = []
@export var enemies_max_weight: float = 100.0


@export_category("Formation")
@export var formation_spacing := 3.0


@export_category("Attack Queue")
@export var attack_cooldown := 1.0

var attack_cooldown_timer := 0.0


@export_category("Exports")
@export var player: Node3D
@export var test_Enemy: EncounterEnemyData


var world: World

var is_battle := false

var current_weight: float = 0.0
var enemies: Array[Encounter_Enemy] = []

var attacker: Encounter_Enemy = null

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

# ============================ SPAWN ===========================================

func spawn_random_group() -> void:
	if enemy_pool.is_empty():
		push_warning("Enemy_Encounter: enemy_pool is empty!")
		return

	var attempts := 0
	var max_attempts := 50

	while attempts < max_attempts:
		attempts += 1

		var remaining := enemies_max_weight - current_weight
		var candidates := enemy_pool.filter(func(data): return data.weight <= remaining)

		if candidates.is_empty():
			break

		var chosen: EncounterEnemyData = candidates[randi() % candidates.size()]
		add_enemy(chosen)
	
	start_encounter()


func add_enemy(enemy_data: EncounterEnemyData) -> Encounter_Enemy:
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

	enemy.initialize(
		player,
		self,
		enemy_data
	)

	is_battle = true
	_reflow_formation()

	return enemy


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

	#if not is_battle:
		#add_test_enemy()


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

# ============================ DEBUG ===========================================

func add_test_enemy() -> void:
	add_enemy(test_Enemy)
	start_encounter()
