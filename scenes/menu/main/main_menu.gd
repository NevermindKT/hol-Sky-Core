extends Control

@export var continue_btn: Button
@export var new_game_btn: Button
@export var settings_btn: Button
@export var titles_btn: Button
@export var exit_btn: Button

@export_file("*.tscn") var menu_scene_path: String

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	continue_btn.pressed.connect(_on_continue_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	
	print("Menu ready!")


func _on_continue_pressed():
	GameFlow.change_scene(menu_scene_path)


func _on_exit_pressed():
	get_tree().quit(0)
