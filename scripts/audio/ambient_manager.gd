extends Node
class_name AmbientManager

@export var ambient_playlist: Array[AudioStream] = []
@export var ambient_volume_db: float = -5.0
@export var ambient_crossfade_time: float = 2.0

@export var random_layers: Array[AmbientLayer] = []

var _ambient_players: Array[AudioStreamPlayer] = []
var _ambient_active_idx: int = 0
var _playlist_pos: int = 0

var _layer_runtime: Array[Dictionary] = []


func _ready() -> void:
	_setup_ambient_playlist()
	_setup_random_layers()


# ============================================================
# ПЛЕЙЛИСТ ЭМБИЕНТОВ
# ============================================================

func _setup_ambient_playlist() -> void:
	if ambient_playlist.is_empty():
		return

	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.volume_db = -80.0
		add_child(p)
		_ambient_players.append(p)

	_play_ambient_track(0)


func _play_ambient_track(index: int) -> void:
	_playlist_pos = index
	var player := _ambient_players[_ambient_active_idx]
	var stream := ambient_playlist[_playlist_pos]

	player.stream = stream
	player.volume_db = -80.0
	player.play()

	var tween_in := create_tween()
	tween_in.tween_property(player, "volume_db", ambient_volume_db, ambient_crossfade_time)

	var length := stream.get_length()
	var wait_time: float = max(length - ambient_crossfade_time, 0.0)
	await get_tree().create_timer(wait_time).timeout

	_crossfade_to_next()


func _crossfade_to_next() -> void:
	var old_player := _ambient_players[_ambient_active_idx]
	_ambient_active_idx = 1 - _ambient_active_idx  # переключаемся на второй плеер

	var next_index := (_playlist_pos + 1) % ambient_playlist.size()

	var tween_out := create_tween()
	tween_out.tween_property(old_player, "volume_db", -80.0, ambient_crossfade_time)
	tween_out.tween_callback(old_player.stop)

	_play_ambient_track(next_index)


# ============================================================
# СЛУЧАЙНЫЕ СЛОИ (ветер, птицы, скрипы...)
# ============================================================

func _setup_random_layers() -> void:
	for layer in random_layers:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = -80.0
		add_child(player)

		var timer := Timer.new()
		timer.one_shot = true
		add_child(timer)

		var runtime := {"layer": layer, "player": player, "timer": timer}
		_layer_runtime.append(runtime)

		timer.timeout.connect(_play_layer_gust.bind(runtime))
		_schedule_next_gust(runtime)


func _schedule_next_gust(runtime: Dictionary) -> void:
	var layer: AmbientLayer = runtime["layer"]
	var timer: Timer = runtime["timer"]
	timer.start(randf_range(layer.interval_min, layer.interval_max))


func _play_layer_gust(runtime: Dictionary) -> void:
	var layer: AmbientLayer = runtime["layer"]
	var player: AudioStreamPlayer = runtime["player"]

	if layer.sounds.is_empty():
		_schedule_next_gust(runtime)
		return

	player.stream = layer.sounds[randi() % layer.sounds.size()]
	player.pitch_scale = 1.0 + randf_range(-layer.pitch_variation, layer.pitch_variation)
	player.volume_db = -80.0
	player.play()

	var tween_in := create_tween()
	tween_in.tween_property(player, "volume_db", layer.volume_db, layer.fade_time)
	await tween_in.finished

	var remaining: float = player.stream.get_length() - layer.fade_time
	if remaining > 0:
		await get_tree().create_timer(remaining).timeout

	var tween_out := create_tween()
	tween_out.tween_property(player, "volume_db", -80.0, layer.fade_time)
	await tween_out.finished

	player.stop()
	_schedule_next_gust(runtime)
