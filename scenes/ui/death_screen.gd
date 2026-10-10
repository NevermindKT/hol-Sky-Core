extends CanvasLayer

@export var restart_btn: Button
@export var exit_btn: Button

@export var hover_sound: AudioStream = preload("res://audio/ui/UI_Button_Hover.wav")
@export var click_sound: AudioStream = preload("res://audio/ui/UI_Button_Click_1.wav")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	Events.player_died.connect(show_self)
	restart_btn.pressed.connect(_restart_pressed)
	exit_btn.pressed.connect(_quit_pressed)
	print("Death screen ready")


func show_self():
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	PauseManager.set_game_over()


func _restart_pressed():
	GameFlow.restart()


func _quit_pressed():
	get_tree().quit(0)


func _on_button_hover():
	SoundManager.play_sfx(hover_sound, 2.0)


func _on_button_click():
	SoundManager.play_sfx(click_sound, 2.0)


func _connect_button_sounds():
	var buttons: Array[Button] = [restart_btn, exit_btn]
	for btn in buttons:
		btn.mouse_entered.connect(_on_button_hover)
		btn.pressed.connect(_on_button_click)
