extends Node3D
class_name Enemy_Encounter

var world: World
@export var player: Node3D
@export var enemies: Array[Encounter_Enemy] = []
@export var test_Enemy: EncounterEnemyData

var is_battle := false

func inialize(_world: World) -> void:
	world = _world
	
	if !get_children():
		print("There no initial enemys in enemy encounter!")
		
	for child in get_children():
		if child is Encounter_Enemy:
			enemies.append(child)
			
			child.initialize(player, self, child.enemy_data)


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
	
	enemy.initialize(
		player,
		self,
		enemy_data
	)
	
	is_battle = true
	
	return enemy


func remove_enemy(enemy: Encounter_Enemy) -> void:
	enemies.erase(enemy)
	print("Encounter is eraising enemy")
	print(is_battle)
	check_battle()


func start_encounter() -> void:
	for enemy in enemies:
		enemy.activate()
	check_battle()


func check_battle() -> void:
	is_battle = is_there_enemies()

	if not is_battle:
		add_test_enemy()
		print("Trying to return enemy")


func is_there_enemies() -> bool:
	return not enemies.is_empty()


func add_test_enemy() -> void:
	add_enemy(test_Enemy)
	start_encounter()
