extends Node
class_name Inventory

@export var rifle_ammo: int
@export var pistol_ammo: int
@export var shotgun_ammo: int

@export var weapon_controller: Weapon_controller

func _ready() -> void:
	weapon_controller.on_fire.connect(consume_ammo)

func consume_ammo():
	pistol_ammo -= 1
	print("ammo: ", pistol_ammo)
