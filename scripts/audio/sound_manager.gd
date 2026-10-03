extends Node

const SFX_POOL_SIZE = 8

var music_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_pool.append(p)

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)


func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	for p in sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return

	sfx_pool[0].stream = stream
	sfx_pool[0].play()


func play_random_sfx(streams: Array[AudioStream], volume_db: float = 0.0, pitch_variation: float = 0.0) -> int:
	if streams.is_empty():
		return -1

	var index: int = randi() % streams.size()
	var pitch: float = 1.0 + randf_range(-pitch_variation, pitch_variation)
	play_sfx(streams[index], volume_db, pitch)
	return index


func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.play()


func stop_music() -> void:
	music_player.stop()
