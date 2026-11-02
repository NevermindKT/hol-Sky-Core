extends Node
class_name MusicManager

enum State { AMBIENT, WARNING, COMBAT, OFF }

@export var car: Car_Movement

@export_category("Music")
@export var music_bus: String = "Music"
@export var music_volume_db: float = 0.0
@export var start_delay: float = 3.0

@export_category("Tracks")
@export var dusk_tracks: Array[AudioStream] = []
@export var dusk_variant := 0
@export var combat_sets: Array[MusicCombatSet] = []
@export var combat_variant := 0
@export var impact: AudioStream
@export var randomize_variants := true

@export_category("Mix")
@export var ambient_volume_db := -2.0
@export var ambient_during_warning_db := -14.0
@export var warning_volume_db := 1.0
@export var combat_volume_db := 0.0
@export var impact_volume_db := -1.0
@export var low_hp_drums_db := -3.0
@export_range(0.0, 1.0, 0.01) var low_hp_ratio := 0.35

@export_category("Fades")
@export var start_fade_in := 6.0
@export var ambient_fade_in := 5.0
@export var ambient_fade_out := 2.0
@export var warning_fade_in := 2.5
@export var warning_fade_out := 0.4
@export var combat_fade_out := 3.0
@export var low_hp_fade := 1.5
@export var stop_fade := 2.0
@export var switch_fade := 1.0
@export var warning_timeout := 60.0

@export_category("Speed Muffle")
@export_range(0.0, 1.0) var clean_start_ratio: float = 0.2
@export_range(0.0, 1.0) var clean_end_ratio: float = 0.7
@export var muffled_cutoff_hz: float = 600.0
@export var clean_cutoff_hz: float = 20000.0
@export var transition_speed: float = 2.5

@export_category("Radio Noise")
@export var noise_sound: AudioStream
@export var noise_bus: String = "SFX"
@export var noise_max_volume_db: float = -14.0

@export_category("Gap Noise")
@export var gap_noise_volume_db: float = -10.0
@export var gap_noise_fade_speed: float = 4.0

@export_category("Damage Muffle")
@export var damage_cutoff_hz: float = 300.0
@export var damage_muffle_hold: float = 0.35
@export var damage_recover_speed: float = 2.0
@export var damage_volume_dip_db: float = -6.0

@export_category("Pause Muffle")
@export var pause_cutoff_hz: float = 500.0
@export var pause_volume_db: float = -4.0
@export var pause_fade: float = 0.4

var state := State.AMBIENT
var volume_scale: float = 1.0

var _ambient: Channel
var _warning: Channel
var _combat: Channel
var _impact: AudioStreamPlayer
var _sync: AudioStreamSynchronized
var _noise_player: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var _music_bus_idx: int = -1
var _clean: float = 1.0

var _in_gap: bool = false
var _gap_noise: float = 0.0
var _damage: float = 0.0
var _damage_hold_timer: float = 0.0
var _low_hp := 0.0
var _low_hp_target := 0.0
var _warning_time := 0.0
var _pause := 0.0


class Channel:
	var player: AudioStreamPlayer
	var gain_db := 0.0
	var level := 0.0
	var target := 0.0
	var speed := 1.0

	func _init(parent: Node, bus: StringName, gain: float) -> void:
		player = AudioStreamPlayer.new()
		player.bus = bus
		player.volume_db = -80.0
		gain_db = gain
		parent.add_child(player)

	func fade(to: float, time: float) -> void:
		target = to
		speed = absf(to - level) / maxf(time, 0.01)
		if to > 0.0 and not player.playing and player.stream:
			player.play()

	func cut() -> void:
		level = 0.0
		target = 0.0
		player.stop()

	func update(delta: float, master_db: float) -> void:
		level = move_toward(level, target, speed * delta)
		player.volume_db = gain_db + master_db + linear_to_db(maxf(level, 0.0001))
		if level <= 0.0 and target <= 0.0 and player.playing:
			player.stop()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_lowpass()

	_ambient = Channel.new(self, music_bus, ambient_volume_db)
	_warning = Channel.new(self, music_bus, warning_volume_db)
	_combat = Channel.new(self, music_bus, combat_volume_db)
	_sync = AudioStreamSynchronized.new()
	_apply_dusk_variant()
	_apply_combat_variant()

	_impact = AudioStreamPlayer.new()
	_impact.bus = music_bus
	_impact.stream = impact
	add_child(_impact)

	_noise_player = AudioStreamPlayer.new()
	_noise_player.bus = noise_bus
	_noise_player.volume_db = -80.0
	add_child(_noise_player)

	if noise_sound:
		_noise_player.stream = noise_sound
		_noise_player.play()

	Events.player_take_damage.connect(_on_player_take_damage)
	Events.player_health_changed.connect(_on_player_health_changed)
	Events.encounter_incoming.connect(_on_encounter_incoming)
	Events.encounter_started.connect(_on_encounter_started)
	Events.encounter_ended.connect(_on_encounter_ended)
	Events.player_died.connect(stop_music)
	Events.run_ended.connect(stop_music)
	Events.dawn_started.connect(_on_dawn_started)
	InputController.next_song.connect(next_variant)

	_start_ambient()


func _exit_tree() -> void:
	if Events.player_take_damage.is_connected(_on_player_take_damage):
		Events.player_take_damage.disconnect(_on_player_take_damage)
	if _music_bus_idx >= 0 and _lowpass:
		for i in AudioServer.get_bus_effect_count(_music_bus_idx):
			if AudioServer.get_bus_effect(_music_bus_idx, i) == _lowpass:
				AudioServer.remove_bus_effect(_music_bus_idx, i)
				break


func _process(delta: float) -> void:
	var speed_ratio: float = car.get_speed_ratio() if car else 1.0
	var target_clean := smoothstep(clean_start_ratio, clean_end_ratio, speed_ratio)
	_clean = lerpf(_clean, target_clean, clampf(delta * transition_speed, 0.0, 1.0))

	_update_damage(delta)

	var speed_cutoff: float = muffled_cutoff_hz * pow(clean_cutoff_hz / muffled_cutoff_hz, _clean)
	var hit_cutoff: float = minf(damage_cutoff_hz, speed_cutoff)
	var cutoff: float = hit_cutoff * pow(speed_cutoff / hit_cutoff, 1.0 - _damage)
	var paused := PauseManager.is_paused and not PauseManager.is_photo_mode and not PauseManager.is_game_over
	_pause = move_toward(_pause, 1.0 if paused else 0.0, delta / maxf(pause_fade, 0.01))
	var pause_cutoff: float = minf(pause_cutoff_hz, cutoff)
	_lowpass.cutoff_hz = cutoff * pow(pause_cutoff / cutoff, _pause)

	if state == State.WARNING:
		_warning_time += delta
		if _warning_time > warning_timeout:
			_return_to_ambient()

	_low_hp = move_toward(_low_hp, _low_hp_target, delta / maxf(low_hp_fade, 0.01))
	if _sync.stream_count >= 3:
		_sync.set_sync_stream_volume(1, low_hp_drums_db * _low_hp)
		_sync.set_sync_stream_volume(2, linear_to_db(maxf(_low_hp, 0.0001)))

	var master_db := music_volume_db \
		+ damage_volume_dip_db * _damage \
		+ pause_volume_db * _pause \
		+ linear_to_db(maxf(volume_scale, 0.0001))
	_ambient.update(delta, master_db)
	_warning.update(delta, master_db)
	_combat.update(delta, master_db)

	_gap_noise = move_toward(_gap_noise, 1.0 if _in_gap else 0.0, gap_noise_fade_speed * delta)
	var speed_noise_lin: float = db_to_linear(lerpf(noise_max_volume_db, -80.0, _clean))
	var gap_noise_lin: float = db_to_linear(gap_noise_volume_db) * _gap_noise
	_noise_player.volume_db = linear_to_db(maxf(maxf(speed_noise_lin, gap_noise_lin), 0.0001))


func _update_damage(delta: float) -> void:
	if _damage_hold_timer > 0.0:
		_damage_hold_timer -= delta
		return
	_damage = move_toward(_damage, 0.0, damage_recover_speed * delta)


func _on_player_take_damage(_damage_: float, _source_position: Vector3) -> void:
	trigger_damage_muffle()

# ============================ STATES ==========================================

func _start_ambient() -> void:
	if start_delay > 0.0:
		_in_gap = true
		await get_tree().create_timer(start_delay).timeout
		_in_gap = false
	if state == State.AMBIENT:
		_randomize_dusk()
		_ambient.fade(1.0, start_fade_in)


func _on_encounter_incoming() -> void:
	if state != State.AMBIENT:
		return
	state = State.WARNING
	_warning_time = 0.0
	_randomize_combat()
	_warning.fade(1.0, warning_fade_in)
	_ambient.fade(db_to_linear(ambient_during_warning_db - ambient_volume_db), warning_fade_in)


func _on_encounter_started() -> void:
	if state == State.COMBAT or state == State.OFF:
		return
	if state == State.AMBIENT:
		_randomize_combat()
	state = State.COMBAT
	if impact:
		_impact.volume_db = impact_volume_db + music_volume_db
		_impact.play()
	_warning.fade(0.0, warning_fade_out)
	_ambient.fade(0.0, ambient_fade_out)
	_combat.player.stop()
	_combat.level = 1.0
	_combat.fade(1.0, 0.0)


func _on_encounter_ended() -> void:
	if state != State.COMBAT:
		return
	_combat.fade(0.0, combat_fade_out)
	_return_to_ambient()


func _on_dawn_started() -> void:
	if state == State.WARNING:
		_return_to_ambient()


func _return_to_ambient() -> void:
	state = State.AMBIENT
	_warning.fade(0.0, warning_fade_out)
	_randomize_dusk()
	_ambient.fade(1.0, ambient_fade_in)


func _on_player_health_changed(value: float) -> void:
	if car == null or car.player_status_controller == null:
		return
	var max_health := car.player_status_controller.max_health
	if max_health <= 0.0:
		return
	var ratio := value / max_health
	_low_hp_target = 1.0 if ratio > 0.0 and ratio <= low_hp_ratio else 0.0


func stop_music() -> void:
	state = State.OFF
	_ambient.fade(0.0, stop_fade)
	_warning.fade(0.0, stop_fade)
	_combat.fade(0.0, stop_fade)

# ============================ VARIANTS ========================================

func next_variant() -> void:
	if state == State.COMBAT and combat_sets.size() > 1:
		set_combat_variant((combat_variant + 1) % combat_sets.size())
	elif state != State.COMBAT and dusk_tracks.size() > 1:
		set_dusk_variant((dusk_variant + 1) % dusk_tracks.size())


func _randomize_dusk() -> void:
	if randomize_variants and dusk_tracks.size() > 1 and not _ambient.player.playing:
		dusk_variant = randi() % dusk_tracks.size()
		_apply_dusk_variant()


func _randomize_combat() -> void:
	if randomize_variants and combat_sets.size() > 1 and not _combat.player.playing and not _warning.player.playing:
		combat_variant = randi() % combat_sets.size()
		_apply_combat_variant()


func set_dusk_variant(index: int) -> void:
	dusk_variant = index
	var was_level := _ambient.target
	_ambient.cut()
	_apply_dusk_variant()
	if was_level > 0.0:
		_ambient.fade(was_level, switch_fade)


func set_combat_variant(index: int) -> void:
	combat_variant = index
	var in_combat := state == State.COMBAT
	_combat.cut()
	_warning.cut()
	_apply_combat_variant()
	if in_combat:
		_combat.fade(1.0, switch_fade)
	elif state == State.WARNING:
		_warning.fade(1.0, switch_fade)


func _apply_dusk_variant() -> void:
	_ambient.player.stream = _looped(_pick(dusk_tracks, dusk_variant))


func _apply_combat_variant() -> void:
	var combat_set := _current_set()
	_warning.player.stream = _looped(combat_set.warning if combat_set else null)
	_sync = AudioStreamSynchronized.new()
	if combat_set:
		var layers: Array[AudioStream] = [combat_set.main, combat_set.drums, combat_set.low_hp]
		_sync.stream_count = layers.size()
		for i in layers.size():
			_sync.set_sync_stream(i, _looped(layers[i]))
	_combat.player.stream = _sync


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

# ============================ VOLUME ==========================================

func set_volume_scale(value: float) -> void:
	volume_scale = clampf(value, 0.0, 1.0)


func trigger_damage_muffle() -> void:
	_damage = 1.0
	_damage_hold_timer = damage_muffle_hold


func _setup_lowpass() -> void:
	_music_bus_idx = AudioServer.get_bus_index(music_bus)
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = clean_cutoff_hz
	if _music_bus_idx >= 0:
		AudioServer.add_bus_effect(_music_bus_idx, _lowpass)
	else:
		push_warning("MusicManager: шина '%s' не найдена" % music_bus)
