extends Node
class_name Encounter_Director

@export var enabled: bool = true
var encounter: Enemy_Encounter
var run_manager: Run_manager

@export_category("Pacing")
@export var initial_delay_segments := 4
@export var min_segments_between_encounters := 6
@export var max_segments_between_encounters := 12
@export var warning_time := 5.0

@export_category("Difficulty Scaling")
@export var base_max_weight := 40.0
@export var max_max_weight := 150.0
@export var weight_growth_speed := 1.0
@export var weight_growth_curve: Curve


var segments_since_last_encounter := 0
var segments_until_next_encounter := 0
var _warned := false


func _ready() -> void:
	Events.segment_dispawned.connect(_on_segment_despawned)
	segments_until_next_encounter = initial_delay_segments


func initialize(_encounter: Enemy_Encounter, _run_manager: Run_manager) -> void:
	encounter = _encounter
	run_manager = _run_manager


func _on_segment_despawned() -> void:
	if run_manager.run_ended or run_manager.distance_reached or run_manager.dawn_started:
		return
	if encounter.is_battle:
		return
	if !enabled:
		return
	
	segments_since_last_encounter += 1

	if not _warned and _seconds_to_encounter() <= warning_time:
		_warned = true
		Events.encounter_incoming.emit()
	
	if segments_since_last_encounter >= segments_until_next_encounter:
		_trigger_encounter()


func _seconds_to_encounter() -> float:
	var remaining := segments_until_next_encounter - segments_since_last_encounter
	var car := encounter.player as Car_Movement
	var speed := car.speed if car else run_manager.average_speed
	return remaining * run_manager.segment_length / maxf(speed, 1.0)


func _trigger_encounter() -> void:
	_warned = false
	segments_since_last_encounter = 0
	segments_until_next_encounter = randi_range(
		min_segments_between_encounters,
		max_segments_between_encounters
	)
	
	encounter.enemies_max_weight = _get_scaled_max_weight()
	encounter.spawn_random_group()


func _get_scaled_max_weight() -> float:
	var progress := 0.0

	if run_manager.distance_to_end > 0.0:
		progress = float(run_manager.distance_traveled) / float(run_manager.distance_to_end)

	progress = clampf(progress * weight_growth_speed, 0.0, 1.0)

	if weight_growth_curve:
		progress = weight_growth_curve.sample_baked(progress)

	return lerp(base_max_weight, max_max_weight, progress)
