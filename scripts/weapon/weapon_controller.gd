extends Node
class_name Weapon_controller

@export var fire_point: Marker3D
@export var current_weapon: WeaponData
@onready var car: Car_Movement = $".."

@export var input: InputController

signal on_fire

var ammo := 0
var cooldown := 0.0

func _process(_delta: float) -> void:
	if input.fire:
		fire()
	
	cooldown -= _delta

func fire():
	if cooldown > 0:
		return
	
	on_fire.emit()
	
	cooldown = 1.0 / current_weapon.fire_rate
	current_weapon.fire_behavior.fire(self)
