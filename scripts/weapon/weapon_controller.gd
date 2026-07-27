extends Node
class_name Weapon_controller

@export var fire_point: Marker3D
@export var current_weapon: WeaponData

var ammo := 0
var cooldown := 0.0

func fire():
	if cooldown > 0:
		return
	
	cooldown = 1.0 / current_weapon.fire_rate
	current_weapon.fire_behavior.fire(self)
