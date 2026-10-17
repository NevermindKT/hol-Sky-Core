extends Node
class_name Run_manager

@export var encounter: Enemy_Encounter

var distance_to_end: float
var distance_traveled := 0

var distance_reached := false
var run_ended := false


func initialize(distance: float) -> void:
	distance_to_end = distance
	Events.segment_dispawned.connect(_on_segment_despawned)


func _on_segment_despawned():
	if distance_reached:
		return

	distance_traveled += 1

	Events.level_progress_changed.emit(
		distance_traveled,
		distance_to_end
	)

	if distance_traveled >= distance_to_end:
		distance_reached = true
		_try_end_run()


func _try_end_run() -> void:
	if run_ended:
		return

	if encounter and encounter.is_battle:
		encounter.battle_ended.connect(end_run, CONNECT_ONE_SHOT)
		return

	end_run()


func end_run():
	if run_ended:
		return

	run_ended = true
	Events.run_ended.emit()
