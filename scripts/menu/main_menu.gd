extends Control

@export_category("Buttons")
@export var continue_btn: Button
@export var new_game_btn: Button
@export var settings_btn: Button
@export var titles_btn: Button
@export var exit_btn: Button

@export_category("Sounds")
@export var hover_sound: AudioStream = preload("res://audio/ui/UI_Button_Hover.wav")
@export var click_sound: AudioStream = preload("res://audio/ui/UI_Button_Click_1.wav")

@export_category("Other Menus")
@export var menu_core: Control
@export var settings_menu: CanvasLayer

@export_category("SubViewPort")
@export var sub_viewport: SubViewport


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	continue_btn.pressed.connect(_on_continue_pressed)
	new_game_btn.pressed.connect(GameFlow.new_game)
	continue_btn.disabled = not GameState.has_progress()
	settings_btn.pressed.connect(_on_options_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

	menu_core.exit_requested.connect(_on_menu_core_exit)

	if settings_menu:
		settings_menu.closed.connect(_on_settings_closed)
		settings_menu.visible = false

	_connect_button_sounds()

	if GameState.state == GameState.State.BASE:
		_open_base.call_deferred()
	else:
		GameState.set_state(GameState.State.MAIN_MENU)


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
	if GameState.needs_intro():
		GameFlow.enter_base()
		return
	_open_base()


func _open_base():
	visible = false
	menu_core.open()
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _on_menu_core_exit():
	menu_core.visible = false
	visible = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	GameState.set_state(GameState.State.MAIN_MENU)


func _on_exit_pressed():
	get_tree().quit(0)


func _on_options_pressed():
	if not settings_menu:
		return
	visible = false
	settings_menu.visible = true


func _on_settings_closed():
	visible = true
	settings_menu.visible = false
