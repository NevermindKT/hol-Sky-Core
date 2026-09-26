extends Control

@export var fullscreen_checkbox: CheckButton
@export var vsync_checkbox: CheckButton


func _ready() -> void:
	fullscreen_checkbox.button_pressed = Settings.is_fullscreen
	vsync_checkbox.button_pressed = Settings.vsync_enabled

	fullscreen_checkbox.toggled.connect(Settings.set_fullscreen)
	vsync_checkbox.toggled.connect(Settings.set_vsync)
