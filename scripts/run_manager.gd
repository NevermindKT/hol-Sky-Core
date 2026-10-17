extends Node
class_name Run_manager

@export var encounter: Enemy_Encounter
@export var segment_length := 55.0
@export var average_speed := 55.0
@export var dawn_time_multiplier := 1.5

var distance_to_end: float
var distance_traveled := 0

var time_limit := 0.0
var time_left := 0.0
var _shown_seconds := -1

var distance_reached := false
var run_ended := false
var dawn_started := false
var _timer_running := false


func initialize(distance: float) -> void:
	distance_to_end = distance
	time_limit = distance * segment_length / average_speed * dawn_time_multiplier
	time_left = time_limit

	Events.segment_dispawned.connect(_on_segment_despawned)
	Events.run_started.connect(_on_run_started)


func _on_run_started() -> void:
	_timer_running = true
	_emit_time_left()


func _process(delta: float) -> void:
	if !_timer_running or run_ended:
		return

	time_left -= delta
	_emit_time_left()

	if time_left <= 0.0:
		start_dawn()


func _emit_time_left() -> void:
	var seconds := maxi(ceili(time_left), 0)
	if seconds == _shown_seconds:
		return
	_shown_seconds = seconds
	Events.dawn_time_changed.emit(seconds)


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


func start_dawn() -> void:
	time_left = 0.0
	_emit_time_left()
	_timer_running = false
	dawn_started = true
	Events.dawn_started.emit()
