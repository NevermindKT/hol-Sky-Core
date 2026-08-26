extends Node3D
class_name Enemy_Encounter


@export var player: Node3D
@export var enemies: Array[Encounter_Enemy] = []
@export var world: World

func inialize() -> void:
	if !get_children():
		print("There no initial enemys in enemy encounter!")
		
	for child in get_children():
		if child is Encounter_Enemy:
			enemies.append(child)
			
			child.initialize(player, self)


func add_enemy(enemy: Encounter_Enemy) -> void:
	self.add_child(enemy)
	enemies.append(enemy)
	enemy.initialize(player, self)


func start_encounter() -> void:
	for enemy in enemies:
		enemy.activate()
