extends CanvasLayer

@export_category("Containers")
@export var categories_con: VBoxContainer
@export var setting_content_con: Control

@export_category("Buttons")
@export var audio_category_btn: Button
@export var video_category_btn: Button
@export var back_btn: Button


@export_category("Panels")
@export var audio_panel: Control
@export var video_panel: Control

signal closed

@export var hover_sound: AudioStream = preload("res://audio/ui/UI_Button_Hover.wav")
@export var click_sound: AudioStream = preload("res://audio/ui/UI_Button_Click_1.wav")


func _ready() -> void:
	audio_category_btn.pressed.connect(_show_panel.bind(audio_panel))
	video_category_btn.pressed.connect(_show_panel.bind(video_panel))
	back_btn.pressed.connect(_on_close_pressed)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_connect_button_sounds()
	_show_panel(audio_panel)


func _connect_button_sounds():
	var buttons: Array[Button] = [audio_category_btn, video_category_btn, back_btn]
	for btn in buttons:
		btn.mouse_entered.connect(_on_button_hover)
		btn.pressed.connect(_on_button_click)


func _on_button_hover():
	SoundManager.play_sfx(hover_sound)


func _on_button_click():
	SoundManager.play_sfx(click_sound)


func _show_panel(panel: Control) -> void:
	for child in setting_content_con.get_children():
		child.visible = child == panel


func _on_close_pressed() -> void:
	Settings.save_settings()
	closed.emit()
