extends Node

#-------------- PLAYER
signal player_died
signal player_heal(heal: float)
signal player_take_damage(damage: float)
signal player_health_changed(value: float)

#-------------- PLAYER MOVEMENT

#-------------- UI
signal hud_update_weapon(weapon: WeaponData)

#-------------- WEAPONS
signal weapon_set(weapon: WeaponData)
signal magazine_count_changed(ammo: float)

signal reload_started(duration: float)
signal reload_finished

#-------------- ROAD/LEVEL
signal segment_dispawned
signal level_progress_changed(current, max)
signal segment_spawned(segment: Road_segment)
signal weather_changed()
signal world_curve_trimmed(removed_length: float)
signal cosmetic_curve_trimmed(removed_length: float)

#-------------- RUN
signal run_started
signal run_ended
