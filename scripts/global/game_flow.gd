extends Node
class_name RestartManager

signal restart_requested

const MENU_SCENE := "res://scenes/menu/menuCore.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const LOADING_SCREEN := preload("res://scenes/ui/loading_screen.tscn")
const MAP_SCRIPT := preload("res://scripts/menu/map/map_main.gd")
const DEFAULT_DIFFICULTY := &"normal"
const DIFFICULTIES := {
	&"easy": preload("res://resources/difficulty/easy.tres"),
	&"normal": preload("res://resources/difficulty/normal.tres"),
	&"hard": preload("res://resources/difficulty/hard.tres"),
}

var difficulty: RunDifficulty = DIFFICULTIES[DEFAULT_DIFFICULTY]
var in_run := false
var target_base_id := -1
var arrived_base_id := -1

var _loading_screen: Loading_Overlay
var _changing := false


func _ready() -> void:
	_loading_screen = LOADING_SCREEN.instantiate()
	add_child(_loading_screen)
	Events.run_ended.connect.call_deferred(_on_run_ended)
	InputController.debug_reset_save.connect.call_deferred(reset_local_save)


func _on_run_ended() -> void:
	if target_base_id == -1:
		return

	for row in BaseInventoryManager.get_rows("Bases"):
		row["ISActive"] = 1 if int(row.get("ID", -1)) == target_base_id else 0

	BaseInventoryManager.save_data()
	arrived_base_id = target_base_id


func reset_local_save() -> void:
	BaseInventoryManager.reset_save()
	UpgradeManager.load_saved_levels()
	target_base_id = -1
	arrived_base_id = -1
	MAP_SCRIPT.quest_visited_bases = {102: [], 104: []}
	GameLog.print("Local save reset")

	var scene := get_tree().current_scene
	if scene and not scene.scene_file_path.is_empty():
		change_scene(scene.scene_file_path)


func get_difficulty(id: StringName) -> RunDifficulty:
	return DIFFICULTIES.get(id, DIFFICULTIES[DEFAULT_DIFFICULTY])


func start_run(new_difficulty: RunDifficulty = null) -> void:
	if new_difficulty != null:
		difficulty = new_difficulty
	change_scene(GAME_SCENE)


func restart() -> void:
	start_run()


func go_to_menu() -> void:
	change_scene(MENU_SCENE)


func change_scene(path: String) -> void:
	if _changing:
		return
	_changing = true

	in_run = false
	get_tree().paused = true
	BoostManager.clear_active()
	Engine.time_scale = 1.0
	restart_requested.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	ResourceLoader.load_threaded_request(path)
	await _loading_screen.show_screen()

	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var scene := ResourceLoader.load_threaded_get(path) as PackedScene

	get_tree().paused = false
	get_tree().change_scene_to_packed(scene)

	if path == GAME_SCENE:
		await Events.run_started
	else:
		await get_tree().process_frame
		await get_tree().process_frame

	_changing = false
	await _loading_screen.hide_screen()
