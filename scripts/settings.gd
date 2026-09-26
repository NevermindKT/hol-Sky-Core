extends Node

const SAVE_PATH := "user://settings.cfg"

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0

var is_fullscreen: bool = false
var vsync_enabled: bool = true

var _master_bus_idx: int
var _music_bus_idx: int
var _sfx_bus_idx: int


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


#---------------- VIDEO

func set_fullscreen(value: bool) -> void:
	is_fullscreen = value
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED
	)


func set_vsync(value: bool) -> void:
	vsync_enabled = value
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
	)


#---------------- PERSISTENCE

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("video", "fullscreen", is_fullscreen)
	config.set_value("video", "vsync", vsync_enabled)
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


func _apply_all() -> void:
	set_master_volume(master_volume)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)
	set_fullscreen(is_fullscreen)
	set_vsync(vsync_enabled)
