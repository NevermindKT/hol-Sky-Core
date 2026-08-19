extends Node3D
class_name Encounter_Enemy

@export var damage: float
@export var health: Health

@onready var hitbox: Area3D = $Hitbox
@onready var crit_hitbox: Area3D = $CritHitbox

func attak():
	pass


func take_damage(value: float) -> void:
	pass


func death() -> void:
	
	
	self.queue_free()
