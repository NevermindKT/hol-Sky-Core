extends Control

@export_category("Options")
@export var resolution_option: OptionButton
@export var fps_limit_option: OptionButton
@export var ground_distance_option: OptionButton

@export_category("CheckButtons")
@export var fullscreen_checkbox: CheckButton
@export var vsync_checkbox: CheckButton
@export var overlay_checkbox: CheckButton
@export var fog_btn: CheckButton

@export_category("Sliders")
@export var fov_slider: HSlider
@export var current_fov_label: Label

@export var ui_slider: HSlider
@export var current_ui_scale_label: Label

@export var gamma_slider: HSlider
@export var current_gamma_label: Label


func _ready() -> void:
	fullscreen_checkbox.button_pressed = Settings.is_fullscreen
	
	vsync_checkbox.button_pressed = Settings.vsync_enabled
	
	fog_btn.button_pressed = Settings.volumetric_fog_enabled
	fog_btn.toggled.connect(Settings.set_volumetric_fog_enabled)
	
	overlay_checkbox.button_pressed = Settings.overlay_enabled
	overlay_checkbox.toggled.connect(Settings.set_overlay)

	_populate_resolution_options()
	resolution_option.selected = Settings.resolution_index

	_populate_fps_limit_options()
	fps_limit_option.selected = Settings.fps_limit_index
	fps_limit_option.item_selected.connect(Settings.set_fps_limit_index)

	_populate_ground_distance_options()
	ground_distance_option.selected = Settings.ground_distance_index
	ground_distance_option.item_selected.connect(Settings.set_ground_distance_index)
	Settings.language_changed.connect(_populate_ground_distance_options)

	fov_slider.value_changed.connect(show_current_fov)
	fov_slider.value = Settings.camera_fov

	ui_slider.value_changed.connect(show_current_ui_scale)
	ui_slider.value = Settings.ui_scale

	gamma_slider.value_changed.connect(Settings.set_ps1_gamma)
	gamma_slider.value_changed.connect(show_current_gamma)
	gamma_slider.value = Settings.ps1_gamma.x

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


func _populate_ground_distance_options() -> void:
	var selected := Settings.ground_distance_index
	ground_distance_option.clear()
	for option_name in Settings.GROUND_DISTANCE_NAMES:
		ground_distance_option.add_item(tr(option_name))
	ground_distance_option.selected = selected


func show_current_fov(value: float):
	current_fov_label.text = str(int(value))


func show_current_ui_scale(value: float):
	current_ui_scale_label.text = str(value)


func show_current_gamma(value: float):
	current_gamma_label.text = "%.2f" % value
