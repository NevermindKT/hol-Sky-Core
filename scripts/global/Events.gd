extends Node

#-------------- PLAYER
signal player_take_damage(damage: float)
signal player_died

#-------------- PLAYER MOVEMENT
signal dodge

#-------------- WEAPONS
signal reload_started(duration: float)
signal reload_finished

signal reload
signal weapon_change_up
signal weapon_change_down

#-------------- ROAD/LEVEL
signal segment_dispawned()
signal level_progress_changed(current, max)
signal segment_spawned(segment: Road_segment)

#-------------- RUN
signal run_started
signal run_ended
