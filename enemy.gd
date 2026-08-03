extends Node3D
class_name Enemy

@export var health: float
@export var damage: float

@onready var hitbox: Area3D = $Hitbox
@onready var crit_hitbox: Area3D = $CritHitbox

func attak():
	pass

func death():
	pass
