extends Node
class_name RestartManager

signal restart_requested

const MENU_SCENE := "res://scenes/menu/menuCore.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const LOADING_SCREEN := preload("res://scenes/ui/loading_screen.tscn")
const DEFAULT_DIFFICULTY := &"normal"
const DIFFICULTIES := {
	&"easy": preload("res://resources/difficulty/easy.tres"),
	&"normal": preload("res://resources/difficulty/normal.tres"),
	&"hard": preload("res://resources/difficulty/hard.tres"),
}

var difficulty: RunDifficulty = DIFFICULTIES[DEFAULT_DIFFICULTY]
var in_run := false

var _loading_screen: Loading_Overlay
var _changing := false


func _ready() -> void:
	_loading_screen = LOADING_SCREEN.instantiate()
	add_child(_loading_screen)


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
