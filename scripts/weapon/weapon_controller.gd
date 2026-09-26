extends Node
class_name Weapon_controller

var current_weapon: WeaponState

@export var gun: GunMove
@export var car: Car_Movement
@export var shell_ejector: Shell_Ejector
@export var player_weapons: Array[WeaponState]

@export var inventory: Inventory

var cooldown := 0.0
var current_spread: float = 0.0


func initialize() -> void:
	InputController.reload.connect(reload)
	InputController.next_weapon.connect(next_weapon)
	InputController.previous_weapon.connect(previous_weapon)
	
	set_weapon(player_weapons[0], 0)
	fill_all_magazines()


func _process(_delta: float) -> void:
	if InputController.fire:
		fire()
	
	cooldown -= _delta
	
	if current_weapon:
		var max_spread := UpgradeManager.get_modified(&"less_spread", current_weapon.data.max_spread)
		current_spread = clamp(
			current_spread - current_weapon.data.bloom_recovery_rate * _delta,
			current_weapon.data.base_spread,
			max_spread
		)
		Events.spread_changed.emit(current_spread)


func fire():
	if current_weapon.is_reloading:
		return

	if cooldown > 0:
		return

	if current_weapon.ammo <= 0:
		reload()
		return
	
	var bullet_save_chance := UpgradeManager.get_modified(&"bullet_saving", 0.0)
	var bullet_saved := randf() < bullet_save_chance
	
	if not bullet_saved:
		current_weapon.ammo -= 1
	
	Events.magazine_count_changed.emit(current_weapon.ammo)
	gun.muzzle_flash.play(false, 1.0, bullet_saved)
	gun.play_bolt_recoil(0.8, 0.04, 0.12)
	SoundManager.play_random_sfx(current_weapon.data.fire_sounds, 0.0, current_weapon.data.fire_pitch_variation)

	var fire_rate := UpgradeManager.get_modified(&"rate_of_fire", current_weapon.data.fire_rate)
	
	cooldown = 1.0 / fire_rate
	current_weapon.data.fire_behavior.fire(self, bullet_saved)

	if shell_ejector:
		shell_ejector.eject(current_weapon.data.shell_type)

	var bloom_per_shot := UpgradeManager.get_modified(&"less_recoil", current_weapon.data.bloom_per_shot)
	var max_spread := UpgradeManager.get_modified(&"less_spread", current_weapon.data.max_spread)

	current_spread = min(
		max_spread,
		current_spread + bloom_per_shot
	)
	Events.spread_changed.emit(current_spread)


func get_spread_ratio() -> float:
	if current_weapon == null:
		return 0.0

	var max_spread := UpgradeManager.get_modified(&"less_spread", current_weapon.data.max_spread)

	if max_spread <= 0.0:
		return 0.0

	return clamp(current_spread / max_spread, 0.0, 1.0)


func reload() -> bool:
	if current_weapon.is_reloading:
		return false

	var magazine_capacity := UpgradeManager.get_modified(&"expanded_magazine", current_weapon.data.magazine_capacity)

	if current_weapon.ammo >= magazine_capacity:
		return false

	var need = magazine_capacity - current_weapon.ammo

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
		var magazine_capacity := UpgradeManager.get_modified(&"expanded_magazine", weapon.data.magazine_capacity)
		var need := magazine_capacity - weapon.ammo
		
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

	set_weapon(player_weapons[index], 1)


func previous_weapon():
	var index := player_weapons.find(current_weapon)

	index -= 1

	if index < 0:
		index = player_weapons.size() - 1

	set_weapon(player_weapons[index], -1)


func set_weapon(weapon: WeaponState, direction: int):
	if current_weapon != null:
			if current_weapon.is_reloading:
				current_weapon.is_reloading = false
				Events.reload_finished.emit()

	current_weapon = weapon
	Events.weapon_set.emit(current_weapon.data, direction)
	Events.magazine_count_changed.emit(current_weapon.ammo)
