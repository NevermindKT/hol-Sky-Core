extends Node

#-------------- PLAYER
signal player_died
signal player_heal(heal: float)
signal player_take_damage(damage: float, source_position: Vector3)
signal player_health_changed(value: float)
signal player_stamina_changed(value: float)

#-------------- PLAYER MOVEMENT

#-------------- UI
signal hud_update_weapon(weapon: WeaponData)

#-------------- WEAPONS
signal weapon_set(weapon: WeaponData, direction: int)
signal magazine_count_changed(ammo: float)

signal reload_started(duration: float)
signal reload_finished

signal spread_changed(ratio: float)
signal critical_hit(position: Vector3)

signal turret_rotation_changed(angle: float)

#-------------- ROAD/LEVEL
signal segment_dispawned
signal level_progress_changed(current, max)
signal segment_spawned(segment: Road_segment)
signal weather_changed()
signal world_curve_trimmed(removed_length: float)

#-------------- UPGRADES
signal upgrade_purchased(upgrade: UpgradeData)

#-------------- VISION
signal thermal_vision_changed(active: bool)
var thermal_vision_active := false

#-------------- RUN
signal run_started
signal run_ended
