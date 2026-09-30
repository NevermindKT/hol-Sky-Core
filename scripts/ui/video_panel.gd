extends Control

@export var fullscreen_checkbox: CheckButton
@export var vsync_checkbox: CheckButton
@export var resolution_option: OptionButton
@export var fov_slider: HSlider
@export var fps_limit_option: OptionButton
@export var ui_slider: HSlider

@export var current_fov_label: Label
@export var current_ui_scale_label: Label


func _ready() -> void:
	fullscreen_checkbox.button_pressed = Settings.is_fullscreen
	vsync_checkbox.button_pressed = Settings.vsync_enabled

	_populate_resolution_options()
	resolution_option.selected = Settings.resolution_index

	_populate_fps_limit_options()
	fps_limit_option.selected = Settings.fps_limit_index
	fps_limit_option.item_selected.connect(Settings.set_fps_limit_index)

	fov_slider.value_changed.connect(show_current_fov)
	fov_slider.value = Settings.camera_fov

	ui_slider.value_changed.connect(show_current_ui_scale)
	ui_slider.value = Settings.ui_scale

	resolution_option.item_selected.connect(Settings.set_resolution_index)
	fullscreen_checkbox.toggled.connect(Settings.set_fullscreen)
	vsync_checkbox.toggled.connect(Settings.set_vsync)
	
	fov_slider.value_changed.connect(Settings.set_camera_fov)
	ui_slider.value_changed.connect(Settings.set_ui_scale)


func _populate_resolution_options() -> void:
	resolution_option.clear()
	for res in Settings.RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])


func _populate_fps_limit_options() -> void:
	fps_limit_option.clear()
	for limit in Settings.FPS_LIMITS:
		fps_limit_option.add_item("%d FPS" % limit)


func show_current_fov(value: float):
	current_fov_label.text = str(int(value))


func show_current_ui_scale(value: float):
	current_ui_scale_label.text = str(value)
