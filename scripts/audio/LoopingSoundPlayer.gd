extends Node
class_name LoopingSoundPlayer

@export var start_sound: AudioStream
@export var loop_sound: AudioStream
@export var end_sound: AudioStream

@export var bus: String = "SFX"

enum State { IDLE, STARTING, LOOPING, ENDING }
var state: State = State.IDLE

var _one_shot_player: AudioStreamPlayer
var _loop_player: AudioStreamPlayer


func _ready() -> void:
	_one_shot_player = AudioStreamPlayer.new()
	_one_shot_player.bus = bus
	add_child(_one_shot_player)

	_loop_player = AudioStreamPlayer.new()
	_loop_player.bus = bus
	add_child(_loop_player)


func start() -> void:
	if state == State.STARTING or state == State.LOOPING:
		return

	if start_sound:
		state = State.STARTING
		_one_shot_player.stream = start_sound
		_set_loop(_one_shot_player, false)
		_one_shot_player.play()
		if not _one_shot_player.finished.is_connected(_on_start_finished):
			_one_shot_player.finished.connect(_on_start_finished, CONNECT_ONE_SHOT)
	else:
		_begin_loop()


func _on_start_finished() -> void:
	if state == State.STARTING:
		_begin_loop()


func _begin_loop() -> void:
	state = State.LOOPING
	if loop_sound:
		_loop_player.stream = loop_sound
		_set_loop(_loop_player, true)
		_loop_player.play()
		get_tree().create_timer(0.5).timeout.connect(func():
			print("loop playing? ", _loop_player.playing, " pos: ", _loop_player.get_playback_position(), " vol: ", _loop_player.volume_db)
		)


func stop() -> void:
	if state == State.IDLE or state == State.ENDING:
		return

	state = State.ENDING
	_loop_player.stop()
	_one_shot_player.stop()

	if end_sound:
		_one_shot_player.stream = end_sound
		_set_loop(_one_shot_player, false)
		_one_shot_player.play()
		if not _one_shot_player.finished.is_connected(_on_end_finished):
			_one_shot_player.finished.connect(_on_end_finished, CONNECT_ONE_SHOT)
	else:
		state = State.IDLE


func _on_end_finished() -> void:
	state = State.IDLE


func set_volume_db(value: float) -> void:
	_one_shot_player.volume_db = value
	_loop_player.volume_db = value


func set_pitch(value: float) -> void:
	_one_shot_player.pitch_scale = value
	_loop_player.pitch_scale = value


func _set_loop(player: AudioStreamPlayer, loop: bool) -> void:
	var stream := player.stream
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = loop
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
