extends Node
class_name Run_manager

var distance_to_end: float
var distance_traveled := 0

var run_ended := false


func initialize(distance: float) -> void:
	distance_to_end = distance
	Events.segment_dispawned.connect(_on_segment_despawned)


func _on_segment_despawned():
	distance_traveled += 1

	Events.level_progress_changed.emit(
		distance_traveled,
		distance_to_end
	)

	if distance_traveled >= distance_to_end:
		if !run_ended:
			end_run()


func end_run():
	run_ended = true
	print("Run ended.")
	Events.run_ended.emit()
