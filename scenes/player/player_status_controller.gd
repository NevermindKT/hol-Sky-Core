extends Node
class_name Player_Status_Controller

var current_health: float
@export var max_health: float

func initialize() -> void:
	current_health = max_health
	
	Events.player_heal.connect(heal)
	Events.player_take_damage.connect(take_damage)

	Events.player_health_changed.emit(current_health)


func heal(heal_value: float) -> void:
	current_health += heal_value
	clamp_health()

	Events.player_health_changed.emit(current_health)


func take_damage(damage_value: float) -> void:
	print("Player taked damage!")

	if current_health > max_health * 0.1:
		if current_health - damage_value <= 0.0:
			one_shot_protect()
			Events.player_health_changed.emit(current_health)
			return

	current_health -= damage_value
	clamp_health()

	Events.player_health_changed.emit(current_health)

	if is_dead():
		death()


func clamp_health() -> void:
	current_health = clampf(current_health, 0.0, max_health)


func is_dead() -> bool:
	return current_health <= 0.0


func death() -> void:
	print("player is dead!")
	Events.player_died.emit()


func one_shot_protect() -> void:
	current_health = max_health * 0.01
