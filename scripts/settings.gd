extends Node

const SAVE_PATH := "user://settings.cfg"

var _view_container: SubViewportContainer
var _game_viewport: SubViewport

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0

var is_fullscreen: bool = false
var vsync_enabled: bool = true
var resolution_index: int = 0
var camera_fov: float = 75.0

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

signal fov_changed(value: float)

var _master_bus_idx: int
var _music_bus_idx: int
var _sfx_bus_idx: int

var fps_limit_index: int = 0
const FPS_LIMITS: Array[int] = [60, 75, 90, 120, 144]

var _hud: CanvasLayer
var ui_scale: float = 1.0

func _ready() -> void:
	_master_bus_idx = AudioServer.get_bus_index("Master")
	_music_bus_idx = AudioServer.get_bus_index("Music")
	_sfx_bus_idx = AudioServer.get_bus_index("SFX")

	load_settings()
	_apply_all()


#---------------- AUDIO

func set_master_volume(value: float) -> void:
	master_volume = value
	AudioServer.set_bus_volume_db(_master_bus_idx, linear_to_db(value))


func set_music_volume(value: float) -> void:
	music_volume = value
	AudioServer.set_bus_volume_db(_music_bus_idx, linear_to_db(value))


func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	AudioServer.set_bus_volume_db(_sfx_bus_idx, linear_to_db(value))


#------------------------------------------------------------------------- VIDEO


func register_viewport(viewport: SubViewport, container: SubViewportContainer) -> void:
	_game_viewport = viewport
	_view_container = container
	_apply_render_resolution(RESOLUTIONS[resolution_index])


func _apply_render_resolution(res: Vector2i) -> void:
	if not is_instance_valid(_view_container):
		return

	var screen_size := DisplayServer.screen_get_size()
	var shrink := maxi(1, roundi(float(screen_size.x) / float(res.x)))
	_view_container.stretch_shrink = shrink


func set_resolution_index(index: int) -> void:
	resolution_index = index
	var res := RESOLUTIONS[index]

	if is_fullscreen:
		_apply_render_resolution(res)
	else:
		if is_instance_valid(_view_container):
			_view_container.stretch_shrink = 1
		DisplayServer.window_set_size(res)
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen_size - res) / 2)


func set_fullscreen(value: bool) -> void:
	is_fullscreen = value
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED
	)

	if value:
		_apply_render_resolution(RESOLUTIONS[resolution_index])
	else:
		set_resolution_index(resolution_index)


func _reset_render_resolution() -> void:
	var root := Engine.get_main_loop().root as Window
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO


func set_vsync(value: bool) -> void:
	vsync_enabled = value
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
	)


func set_camera_fov(value: float) -> void:
	camera_fov = value
	fov_changed.emit(value)


func set_fps_limit_index(index: int) -> void:
	fps_limit_index = index
	Engine.max_fps = FPS_LIMITS[index]


func register_hud(hud: HUD) -> void:
	_hud = hud
	_apply_ui_scale()


func set_ui_scale(value: float) -> void:
	ui_scale = value
	_apply_ui_scale()


func _apply_ui_scale() -> void:
	if is_instance_valid(_hud):
		_hud.apply_ui_scale(ui_scale)

#------------------------------------------------------------------- PERSISTENCE


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("video", "fullscreen", is_fullscreen)
	config.set_value("video", "vsync", vsync_enabled)
	config.set_value("video", "resolution_index", resolution_index)
	config.set_value("video", "fov", camera_fov)
	config.set_value("video", "fps_limit_index", fps_limit_index)
	config.set_value("video", "ui_scale", ui_scale)
	config.save(SAVE_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	master_volume = config.get_value("audio", "master_volume", master_volume)
	music_volume = config.get_value("audio", "music_volume", music_volume)
	sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
	is_fullscreen = config.get_value("video", "fullscreen", is_fullscreen)
	vsync_enabled = config.get_value("video", "vsync", vsync_enabled)
	resolution_index = config.get_value("video", "resolution_index", resolution_index)
	camera_fov = config.get_value("video", "fov", camera_fov)
	fps_limit_index = config.get_value("video", "fps_limit_index", fps_limit_index)
	ui_scale = config.get_value("video", "ui_scale", ui_scale)


func _apply_all() -> void:
	set_master_volume(master_volume)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)
	set_fullscreen(is_fullscreen)
	set_vsync(vsync_enabled)
	set_fps_limit_index(fps_limit_index)
	set_ui_scale(ui_scale)
