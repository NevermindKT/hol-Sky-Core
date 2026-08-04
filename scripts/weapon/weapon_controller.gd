extends Node
class_name Weapon_controller

@export var fire_point: Marker3D
@export var input: InputController
@export var current_weapon: WeaponData
@onready var car: Car_Movement = $".."
@onready var inventory: Inventory = $"../Inventory"


var ammo := 0
var cooldown := 0.0
var is_reloading := false


func _ready() -> void:
	input.reload.connect(reload)
	reload()


func _process(_delta: float) -> void:
	if input.fire:
		fire()
	
	cooldown -= _delta

func fire():
	if is_reloading:
		return

	if cooldown > 0:
		return

	if ammo <= 0:
		reload()
		return

	ammo -= 1

	cooldown = 1.0 / current_weapon.fire_rate
	current_weapon.fire_behavior.fire(self)


func reload() -> bool:
	if is_reloading:
		return false

	if ammo >= current_weapon.magazine_capacity:
		return false

	var need = current_weapon.magazine_capacity - ammo

	if inventory.get_ammo(current_weapon.ammo_type) <= 0:
		return false

	is_reloading = true

	await get_tree().create_timer(current_weapon.reload_duration).timeout

	var loaded = inventory.consume_ammo(
		current_weapon.ammo_type,
		need
	)

	ammo += loaded

	is_reloading = false

	return loaded > 0
