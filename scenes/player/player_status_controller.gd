extends Node
class_name Player_Status_Controller

#const TEST_HEALTH := 100.0

var current_health: float
@export var max_health: float


func intialize():
	#max_health = TEST_HEALTH
	current_health = max_health
	Events.player_heal.connect(heal)
	Events.player_take_damage.connect(take_damage)


func heal(heal_value: float):
	current_health += heal_value
	clamp_health()


func take_damage(damge_value: float):
	current_health -= damge_value
	
	if is_dead():
		death()
	
	clamp_health()


func clamp_health():
	current_health = clampf(current_health, 0.0, max_health)


func is_dead() -> bool:
	return current_health <= 0.0


func death():
	print("player is dead!")
	Events.player_died.emit()
