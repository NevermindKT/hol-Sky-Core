extends Node
class_name Music_Director

enum State { AMBIENT, WARNING, COMBAT, OFF }

@export var car: Car_Movement
@export var bus: StringName = &"Music"

@export_category("Tracks")
@export var dusk_tracks: Array[AudioStream] = []
@export var dusk_variant := 0
@export var combat_sets: Array[MusicCombatSet] = []
@export var combat_variant := 0
@export var impact: AudioStream

@export_category("Mix")
@export var volume_db := 0.0
@export var ambient_volume_db := -2.0
@export var ambient_during_warning_db := -9.0
@export var warning_volume_db := -3.0
@export var combat_volume_db := 0.0
@export var impact_volume_db := -1.0
@export var low_hp_drums_db := -3.0
@export_range(0.0, 1.0, 0.01) var low_hp_ratio := 0.35

@export_category("Fades")
@export var start_fade_in := 6.0
@export var ambient_fade_in := 5.0
@export var ambient_fade_out := 2.0
@export var warning_fade_in := 5.0
@export var warning_fade_out := 0.4
@export var combat_fade_out := 3.0
@export var low_hp_fade := 1.5
@export var stop_fade := 2.0
@export var warning_timeout := 60.0

var state := State.AMBIENT

var _ambient: Channel
var _warning: Channel
var _combat: Channel
var _impact: AudioStreamPlayer
var _sync: AudioStreamSynchronized
var _low_hp := 0.0
var _low_hp_target := 0.0
var _warning_time := 0.0


class Channel:
	var player: AudioStreamPlayer
	var gain_db := 0.0
	var level := 0.0
	var target := 0.0
	var speed := 1.0

	func _init(owner: Node, bus: StringName, stream: AudioStream, gain: float) -> void:
		player = AudioStreamPlayer.new()
		player.bus = bus
		player.stream = stream
		player.volume_db = -80.0
		gain_db = gain
		owner.add_child(player)

	func fade(to: float, time: float) -> void:
		target = to
		speed = absf(to - level) / maxf(time, 0.01)
		if to > 0.0 and not player.playing and player.stream:
			player.play()

	func update(delta: float, master_db: float) -> void:
		level = move_toward(level, target, speed * delta)
		player.volume_db = gain_db + master_db + linear_to_db(maxf(level, 0.0001))
		if level <= 0.0 and target <= 0.0 and player.playing:
			player.stop()


func _ready() -> void:
	var scene := get_tree().current_scene
	if car == null and scene:
		car = scene.find_child("Car", true, false) as Car_Movement

	var combat_set := _current_set()
	_ambient = Channel.new(self, bus, _looped(_pick(dusk_tracks, dusk_variant)), ambient_volume_db)
	_warning = Channel.new(self, bus, _looped(combat_set.warning if combat_set else null), warning_volume_db)

	_sync = AudioStreamSynchronized.new()
	if combat_set:
		var layers: Array[AudioStream] = [combat_set.main, combat_set.drums, combat_set.low_hp]
		_sync.stream_count = layers.size()
		for i in layers.size():
			_sync.set_sync_stream(i, _looped(layers[i]))
	_combat = Channel.new(self, bus, _sync, combat_volume_db)

	_impact = AudioStreamPlayer.new()
	_impact.bus = bus
	_impact.stream = impact
	add_child(_impact)

	Events.encounter_incoming.connect(_on_encounter_incoming)
	Events.encounter_started.connect(_on_encounter_started)
	Events.encounter_ended.connect(_on_encounter_ended)
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.player_died.connect(stop_all)
	Events.run_ended.connect(stop_all)

	_ambient.fade(1.0, start_fade_in)


func _process(delta: float) -> void:
	if state == State.WARNING:
		_warning_time += delta
		if _warning_time > warning_timeout:
			_return_to_ambient(warning_fade_out)

	_low_hp = move_toward(_low_hp, _low_hp_target, delta / maxf(low_hp_fade, 0.01))
	if _sync.stream_count >= 3:
		_sync.set_sync_stream_volume(1, low_hp_drums_db * _low_hp)
		_sync.set_sync_stream_volume(2, linear_to_db(maxf(_low_hp, 0.0001)))

	_ambient.update(delta, volume_db)
	_warning.update(delta, volume_db)
	_combat.update(delta, volume_db)


func _on_encounter_incoming() -> void:
	if state != State.AMBIENT:
		return
	state = State.WARNING
	_warning_time = 0.0
	_warning.fade(1.0, warning_fade_in)
	_ambient.fade(db_to_linear(ambient_during_warning_db - ambient_volume_db), warning_fade_in)
	GameLog.print("Music: warning")


func _on_encounter_started() -> void:
	if state == State.COMBAT or state == State.OFF:
		return
	state = State.COMBAT
	if impact:
		_impact.volume_db = impact_volume_db + volume_db
		_impact.play()
	_warning.fade(0.0, warning_fade_out)
	_ambient.fade(0.0, ambient_fade_out)
	_combat.player.stop()
	_combat.level = 1.0
	_combat.fade(1.0, 0.0)
	GameLog.print("Music: combat")


func _on_encounter_ended() -> void:
	if state != State.COMBAT:
		return
	_combat.fade(0.0, combat_fade_out)
	_return_to_ambient(warning_fade_out)
	GameLog.print("Music: ambient")


func _return_to_ambient(warning_out: float) -> void:
	state = State.AMBIENT
	_warning.fade(0.0, warning_out)
	_ambient.fade(1.0, ambient_fade_in)


func _on_player_health_changed(value: float) -> void:
	if car == null or car.player_status_controller == null:
		return
	var max_health := car.player_status_controller.max_health
	if max_health <= 0.0:
		return
	var ratio := value / max_health
	_low_hp_target = 1.0 if ratio > 0.0 and ratio <= low_hp_ratio else 0.0


func stop_all() -> void:
	state = State.OFF
	_ambient.fade(0.0, stop_fade)
	_warning.fade(0.0, stop_fade)
	_combat.fade(0.0, stop_fade)


func _current_set() -> MusicCombatSet:
	if combat_sets.is_empty():
		return null
	return combat_sets[clampi(combat_variant, 0, combat_sets.size() - 1)]


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
