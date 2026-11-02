extends Node
class_name Menu_Music

@export_category("Tracks")
@export var menu_tracks: Array[AudioStream] = []
@export var menu_variant := 0
@export var base_music: AudioStream
@export var base_backgrounds: Dictionary[StringName, AudioStream] = {}
@export var default_tab: StringName = &"map"
@export var dialogue_music: Dictionary[StringName, AudioStream] = {}
@export var dialogue_backgrounds: Dictionary[StringName, AudioStream] = {}
@export var nervous_layer: AudioStream
@export var nervous_environment: StringName = &"stranger"
@export var nervous_emotions: Array[String] = ["nervous"]
@export var death_stings: Array[AudioStream] = []
@export var death_variant := 0
@export var victory_stings: Array[AudioStream] = []
@export var victory_variant := 0

@export_category("Mix")
@export var music_bus: StringName = &"Music"
@export var background_bus: StringName = &"SFX"
@export var music_volume_db := 6.0
@export var background_volume_db := 6.0
@export var sting_volume_db := 8.0

@export_category("Fades")
@export var crossfade := 2.5
@export var tab_crossfade := 1.2
@export var layer_fade := 2.0
@export var run_fade_out := 1.5
@export var sting_fade_out := 2.5

var current_tab: StringName
var dialogue_environment: StringName
var dialogue_emotion := ""

var _music: Slot
var _background: Slot
var _sting: AudioStreamPlayer
var _sting_tween: Tween
var _nervous := 0.0
var _nervous_target := 0.0


class Slot:
	var owner: Node
	var players: Array[AudioStreamPlayer] = []
	var tweens: Array[Tween] = [null, null]
	var active := 0
	var source: AudioStream
	var volume_db := 0.0

	func _init(parent: Node, bus: StringName, gain_db: float) -> void:
		owner = parent
		volume_db = gain_db
		for i in 2:
			var p := AudioStreamPlayer.new()
			p.bus = bus
			p.volume_db = -80.0
			parent.add_child(p)
			players.append(p)

	func current() -> AudioStreamPlayer:
		return players[active]

	func play(stream: AudioStream, playback: AudioStream, time: float) -> void:
		if stream == source:
			return
		source = stream
		_fade(active, -80.0, time, true)
		if stream == null:
			return
		active = 1 - active
		var p := players[active]
		p.stream = playback
		p.volume_db = -80.0
		p.play()
		_fade(active, volume_db, time, false)

	func _fade(index: int, to_db: float, time: float, stop_after: bool) -> void:
		var p := players[index]
		if tweens[index]:
			tweens[index].kill()
		if not p.playing:
			return
		var t := owner.create_tween()
		t.tween_property(p, "volume_db", to_db, maxf(time, 0.01)).set_trans(Tween.TRANS_SINE)
		if stop_after:
			t.tween_callback(p.stop)
		tweens[index] = t


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = Slot.new(self, music_bus, music_volume_db)
	_background = Slot.new(self, background_bus, background_volume_db)
	_sting = AudioStreamPlayer.new()
	_sting.bus = music_bus
	add_child(_sting)

	GameState.state_changed.connect(_on_state_changed)
	Events.player_died.connect(_on_player_died)
	Events.run_ended.connect(_on_run_ended)
	Events.run_started.connect(_on_state_changed.bind(GameState.State.RUN))
	_on_state_changed.call_deferred(GameState.state)


func _process(delta: float) -> void:
	_nervous = move_toward(_nervous, _nervous_target, delta / maxf(layer_fade, 0.01))
	var stream := _music.current().stream
	if stream is AudioStreamSynchronized and (stream as AudioStreamSynchronized).stream_count > 1:
		(stream as AudioStreamSynchronized).set_sync_stream_volume(1, linear_to_db(maxf(_nervous, 0.0001)))


func _on_state_changed(state: int) -> void:
	if state != GameState.State.SUMMARY:
		_fade_sting()
	match state:
		GameState.State.MAIN_MENU:
			_set_music(_pick(menu_tracks, menu_variant))
			_background.play(null, null, crossfade)
		GameState.State.BASE:
			_set_music(base_music)
			set_base_tab(default_tab if current_tab.is_empty() else current_tab)
		GameState.State.DIALOGUE:
			dialogue_environment = &""
			dialogue_emotion = ""
			_set_music(null)
			_background.play(null, null, crossfade)
		GameState.State.RUN:
			current_tab = &""
			_set_music(null, run_fade_out)
			_background.play(null, null, run_fade_out)


func set_base_tab(tab: StringName) -> void:
	current_tab = tab
	if GameState.state == GameState.State.BASE:
		var stream: AudioStream = base_backgrounds.get(tab)
		_background.play(stream, _looped(stream), tab_crossfade)


func apply_presentation(presentation: Dictionary) -> void:
	if presentation.has("environment") and not str(presentation.environment).is_empty():
		dialogue_environment = StringName(presentation.environment)
	if presentation.has("character") or presentation.has("emotion"):
		dialogue_emotion = str(presentation.get("emotion", ""))
	_nervous_target = 1.0 if dialogue_environment == nervous_environment and dialogue_emotion in nervous_emotions else 0.0
	var music: AudioStream = dialogue_music.get(dialogue_environment)
	if music != _music.source:
		_nervous = _nervous_target
		_set_music(music)
	var bg: AudioStream = dialogue_backgrounds.get(dialogue_environment)
	_background.play(bg, _looped(bg), crossfade)


func _set_music(stream: AudioStream, time := -1.0) -> void:
	var playback := _looped(stream)
	if stream and stream == dialogue_music.get(nervous_environment) and nervous_layer:
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = 2
		sync.set_sync_stream(0, playback)
		sync.set_sync_stream(1, _looped(nervous_layer))
		sync.set_sync_stream_volume(1, linear_to_db(maxf(_nervous, 0.0001)))
		playback = sync
	_music.play(stream, playback, crossfade if time < 0.0 else time)


func _on_player_died() -> void:
	_play_sting(_pick(death_stings, death_variant))


func _on_run_ended() -> void:
	_play_sting(_pick(victory_stings, victory_variant))


func _play_sting(stream: AudioStream) -> void:
	if stream == null:
		return
	if _sting_tween:
		_sting_tween.kill()
	_sting.stream = stream
	_sting.volume_db = sting_volume_db
	_sting.play()


func _fade_sting() -> void:
	if not _sting.playing:
		return
	if _sting_tween:
		_sting_tween.kill()
	_sting_tween = create_tween()
	_sting_tween.tween_property(_sting, "volume_db", -80.0, sting_fade_out)
	_sting_tween.tween_callback(_sting.stop)


func _pick(list: Array[AudioStream], index: int) -> AudioStream:
	if list.is_empty():
		return null
	return list[clampi(index, 0, list.size() - 1)]


func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream
