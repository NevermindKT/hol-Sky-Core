extends Node
class_name Run_stats

signal summary_ready(summary: Dictionary)

var run_time := 0.0
var damage_taken := 0.0
var kills_total := 0
var kills_by_enemy: Dictionary = {}

var _running := true
var _finished := false


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_take_damage.connect(_on_player_take_damage)
	Events.run_ended.connect(finish)


func _process(delta: float) -> void:
	if _running:
		run_time += delta


func _on_enemy_killed(enemy_data: EncounterEnemyData) -> void:
	kills_total += 1
	kills_by_enemy[enemy_data] = kills_by_enemy.get(enemy_data, 0) + 1


func _on_player_take_damage(damage: float, _source_position: Vector3) -> void:
	damage_taken += damage


func finish() -> void:
	if _finished:
		return
	_finished = true
	_running = false
	summary_ready.emit(get_summary())


func get_summary() -> Dictionary:
	var kills: Array[Dictionary] = []
	for data in kills_by_enemy:
		kills.append({"name": data.display_name, "count": kills_by_enemy[data]})
	kills.sort_custom(func(a, b): return a["count"] > b["count"])

	return {
		"time": run_time,
		"damage_taken": damage_taken,
		"kills_total": kills_total,
		"kills": kills,
	}


static func format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
