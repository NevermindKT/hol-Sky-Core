extends Control

@export_category("Buttons")
@export var continue_btn: Button
@export var new_game_btn: Button
@export var settings_btn: Button
@export var titles_btn: Button
@export var exit_btn: Button

@export_category("Scene Path")
@export_file("*.tscn") var menu_scene_path: String

@export_category("Sounds")
@export var hover_sound: AudioStream = preload("res://audio/ui/UI_Button_Hover.wav")
@export var click_sound: AudioStream = preload("res://audio/ui/UI_Button_Click_1.wav")

@export_category("Other Menus")
@export var settings_menu: CanvasLayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	continue_btn.pressed.connect(_on_continue_pressed)
	settings_btn.pressed.connect(_on_options_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)


	settings_menu.closed.connect(_on_settings_closed)
	settings_menu.visible = false

	_connect_button_sounds()


func _connect_button_sounds():
	var buttons: Array[Button] = [continue_btn, new_game_btn, settings_btn, titles_btn, exit_btn]
	for btn in buttons:
		btn.mouse_entered.connect(_on_button_hover)
		btn.pressed.connect(_on_button_click)


func _on_button_hover():
	SoundManager.play_sfx(hover_sound, 2.0)


func _on_button_click():
	SoundManager.play_sfx(click_sound, 2.0)


func _on_continue_pressed():
	GameFlow.change_scene(menu_scene_path)


func _on_exit_pressed():
	get_tree().quit(0)


func _on_options_pressed():
	visible = false
	settings_menu.visible = true


func _on_settings_closed():
	visible = true
	settings_menu.visible = false
