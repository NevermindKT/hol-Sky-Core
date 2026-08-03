extends Node
class_name Weapon_controller

@export var fire_point: Marker3D
@export var input: InputController
@export var current_weapon: WeaponData
@onready var car: Car_Movement = $".."
@onready var inventory: Inventory = $"../Inventory"


var ammo := 0
var cooldown := 0.0

func _ready() -> void:
	input.reload.connect(reload)
	reload()

func _process(_delta: float) -> void:
	if input.fire:
		fire()
	
	cooldown -= _delta

func fire():
	if cooldown > 0:
		return
	
	if ammo <= 0:
		if !reload():
			return
	
	ammo -= 1
	
	print(ammo, "/", current_weapon.magazine_capacity)
	
	cooldown = 1.0 / current_weapon.fire_rate
	current_weapon.fire_behavior.fire(self)

func reload() -> bool:
	if ammo >= current_weapon.magazine_capacity:
		return false

	var need = current_weapon.magazine_capacity - ammo
	var loaded = inventory.consume_ammo(
		current_weapon.ammo_type,
		need
	)

	if loaded == 0:
		return false

	ammo += loaded
	return true
