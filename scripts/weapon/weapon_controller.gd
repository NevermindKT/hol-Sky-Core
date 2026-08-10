extends Node
class_name Weapon_controller

var current_weapon: WeaponState

@export var fire_point: Marker3D
@export var player_weapons: Array[WeaponState]
@onready var inventory: Inventory = $"../Inventory"

var cooldown := 0.0

func initialize() -> void:
	InputController.reload.connect(reload)
	InputController.next_weapon.connect(next_weapon)
	InputController.previous_weapon.connect(previous_weapon)
	
	set_weapon(player_weapons[0])
	fill_all_magazines()


func _process(_delta: float) -> void:
	if InputController.fire:
		fire()
	
	cooldown -= _delta

func fire():
	if current_weapon.is_reloading:
		return

	if cooldown > 0:
		return

	if current_weapon.ammo <= 0:
		reload()
		return

	current_weapon.ammo -= 1
	Events.magazine_count_changed.emit(current_weapon.ammo)

	cooldown = 1.0 / current_weapon.data.fire_rate
	current_weapon.data.fire_behavior.fire(self)


func reload() -> bool:
	if current_weapon.is_reloading:
		return false

	if current_weapon.ammo >= current_weapon.data.magazine_capacity:
		return false

	var need = current_weapon.data.magazine_capacity - current_weapon.ammo

	if inventory.get_ammo(current_weapon.data.ammo_type) <= 0:
		return false

	current_weapon.is_reloading = true
	Events.reload_started.emit(current_weapon.data.reload_duration)

	await get_tree().create_timer(current_weapon.data.reload_duration).timeout
	
	if !current_weapon.is_reloading:
		reload_stop()
		return false

	var loaded = inventory.consume_ammo(
		current_weapon.data.ammo_type,
		need
	)

	current_weapon.ammo += loaded
	
	Events.magazine_count_changed.emit(current_weapon.ammo)
	
	current_weapon.is_reloading = false
	Events.reload_finished.emit()

	return loaded > 0

func reload_stop():
	Events.reload_finished.emit()


func fill_all_magazines():
	for weapon in player_weapons:
		var need := weapon.data.magazine_capacity - weapon.ammo
		
		if need <= 0:
			continue
		
		var loaded := inventory.consume_ammo(
			weapon.data.ammo_type,
			need
		)
		
		weapon.ammo += loaded
	Events.magazine_count_changed.emit(current_weapon.ammo)


func next_weapon():
	var index := player_weapons.find(current_weapon)

	index += 1

	if index >= player_weapons.size():
		index = 0

	set_weapon(player_weapons[index])


func previous_weapon():
	var index := player_weapons.find(current_weapon)

	index -= 1

	if index < 0:
		index = player_weapons.size() - 1

	set_weapon(player_weapons[index])


func set_weapon(weapon: WeaponState):
	if !current_weapon == null:
			if current_weapon.is_reloading:
				current_weapon.is_reloading = false
				Events.reload_finished.emit()

	current_weapon = weapon
	Events.weapon_set.emit(current_weapon.data)
	Events.magazine_count_changed.emit(current_weapon.ammo)
