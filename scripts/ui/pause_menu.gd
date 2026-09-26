extends CanvasLayer
class_name Pause_Menu

@onready var continue_btn: Button = $Menu/ContinueBtn
@onready var options_btn: Button = $Menu/OptionsBtn
@onready var exit_btn: Button = $Menu/ExitBtn

@onready var menu: Control = $Menu
@onready var settings_menu: CanvasLayer = $SettingsMenu

@export var hover_sound: AudioStream = preload("res://audio/ui/UI_Button_Hover.wav")
@export var click_sound: AudioStream = preload("res://audio/ui/UI_Button_Click_1.wav")


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	PauseManager.pause_state_changed.connect(_on_pause_state_changed)
	continue_btn.pressed.connect(_on_continue_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	exit_btn.pressed.connect(_on_quit_pressed)

	settings_menu.closed.connect(_on_settings_closed)
	settings_menu.visible = false

	_connect_button_sounds()


func _connect_button_sounds():
	var buttons: Array[Button] = [continue_btn, options_btn, exit_btn]
	for btn in buttons:
		btn.mouse_entered.connect(_on_button_hover)
		btn.pressed.connect(_on_button_click)


func _on_button_hover():
	SoundManager.play_sfx(hover_sound)


func _on_button_click():
	SoundManager.play_sfx(click_sound)


func _on_pause_state_changed():
	check_visible()


func _on_continue_pressed():
	PauseManager.set_paused(false)
	check_visible()


func _on_options_pressed():
	menu.visible = false
	settings_menu.visible = true


func _on_settings_closed():
	settings_menu.visible = false
	menu.visible = true


func _on_quit_pressed():
	get_tree().quit(0)


func check_visible():
	visible = PauseManager.is_paused

	if PauseManager.is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	if not PauseManager.is_paused:
		menu.visible = true
		settings_menu.visible = false
