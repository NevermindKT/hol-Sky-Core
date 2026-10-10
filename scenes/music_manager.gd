extends Node
class_name MusicManager

@export var car: Car_Movement

@export_category("Music")
@export var tracks: Array[AudioStream] = []
@export var music_bus: String = "Music"
@export var music_volume_db: float = -6.0
@export var gap_between_tracks: float = 1.0

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

var volume_scale: float = 1.0

var _music_player: AudioStreamPlayer
var _noise_player: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var _music_bus_idx: int = -1
var _last_track: int = -1
var _clean: float = 1.0

var _in_gap: bool = false
var _gap_noise: float = 0.0
var _damage: float = 0.0
var _damage_hold_timer: float = 0.0


func _ready() -> void:
	_setup_lowpass()

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = music_bus
	_music_player.finished.connect(_on_track_finished)
	add_child(_music_player)

	_noise_player = AudioStreamPlayer.new()
	_noise_player.bus = noise_bus
	_noise_player.volume_db = -80.0
	add_child(_noise_player)

	if noise_sound:
		_noise_player.stream = noise_sound
		_noise_player.play()

	_play_next_track()

	Events.player_take_damage.connect(_on_player_take_damage)
	InputController.next_song.connect(_play_next_track)


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
	_lowpass.cutoff_hz = hit_cutoff * pow(speed_cutoff / hit_cutoff, 1.0 - _damage)

	_music_player.volume_db = music_volume_db \
		+ damage_volume_dip_db * _damage \
		+ linear_to_db(maxf(volume_scale, 0.0001))

	_gap_noise = move_toward(_gap_noise, 1.0 if _in_gap else 0.0, gap_noise_fade_speed * delta)
	var speed_noise_lin: float = db_to_linear(lerpf(noise_max_volume_db, -80.0, _clean))
	var gap_noise_lin: float = db_to_linear(gap_noise_volume_db) * _gap_noise
	_noise_player.volume_db = linear_to_db(maxf(maxf(speed_noise_lin, gap_noise_lin), 0.0001))


func _update_damage(delta: float) -> void:
	if _damage_hold_timer > 0.0:
		_damage_hold_timer -= delta
		return
	_damage = move_toward(_damage, 0.0, damage_recover_speed * delta)

func _on_player_take_damage(_damage: float, _source_position: Vector3) -> void:
	trigger_damage_muffle()

# ============================ TRACKS ==========================================

func _play_next_track() -> void:
	_in_gap = false
	if tracks.is_empty():
		return

	var index := randi() % tracks.size()
	if tracks.size() > 1:
		while index == _last_track:
			index = randi() % tracks.size()
	_last_track = index

	_music_player.stream = tracks[index]
	_music_player.play()


func _on_track_finished() -> void:
	_in_gap = true
	if gap_between_tracks > 0.0:
		await get_tree().create_timer(gap_between_tracks).timeout
	_play_next_track()


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
