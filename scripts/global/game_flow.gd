extends Node
class_name RestartManager

signal restart_requested

const MENU_SCENE := "res://scenes/menu/menuCore.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const LOADING_SCREEN := preload("res://scenes/ui/loading_screen.tscn")
const DIALOGUE_SCENE := "res://scenes/DialogueMain.tscn"
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

	arrived_base_id = target_base_id
	GameState.progress["pending_arrival"] = arrived_base_id
	GameState.save_progress()


func reset_local_save() -> void:
	if _changing:
		return
	GameState.reset_progress()
	difficulty = DIFFICULTIES[DEFAULT_DIFFICULTY]
	Run_stats.last_summary = {}
	target_base_id = -1
	arrived_base_id = -1
	GameLog.print("Local save reset")
	go_to_menu()


func new_game() -> void:
	reset_local_save()


func enter_base() -> void:
	go_to_menu()


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
	# Normalize UID exports so every entry point uses the same state transitions.
	if path.begins_with("uid://"):
		path = ResourceUID.get_id_path(ResourceUID.text_to_id(path))
	if path == MENU_SCENE:
		GameState.enter_base()
		if GameState.needs_intro():
			path = DIALOGUE_SCENE
	if path == DIALOGUE_SCENE:
		GameState.set_state(GameState.State.DIALOGUE)
	elif path == GAME_SCENE:
		GameState.set_state(GameState.State.RUN)
	elif path != MENU_SCENE:
		GameState.set_state(GameState.State.SUMMARY)

	in_run = false
	get_tree().paused = true
	BoostManager.clear_active()
	Engine.time_scale = 1.0
	restart_requested.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var load_error := ResourceLoader.load_threaded_request(path)
	if load_error != OK:
		push_error("Cannot load scene '%s': %s" % [path, load_error])
		get_tree().paused = false
		_changing = false
		return
	await _loading_screen.show_screen()

	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var scene := ResourceLoader.load_threaded_get(path) as PackedScene
	if scene == null:
		push_error("Failed to load scene '%s'." % path)
		get_tree().paused = false
		_changing = false
		await _loading_screen.hide_screen()
		return

	get_tree().paused = false
	get_tree().change_scene_to_packed(scene)

	if path == GAME_SCENE:
		await Events.run_started
	else:
		await get_tree().process_frame
		await get_tree().process_frame

	_changing = false
	await _loading_screen.hide_screen()
