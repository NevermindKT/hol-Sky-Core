extends Node
class_name EngineSound

@export var engine_loop_sound: AudioStream
@export var bus: String = "SFX"

@export_category("RPM Simulation")
@export_range(0.0, 1.0) var idle_rpm: float = 0.2
@export_range(0.0, 1.0) var launch_rpm: float = 0.55
@export_range(0.0, 1.0) var max_rpm: float = 1.0

@export var rpm_rise_speed: float = 6.0
@export var rpm_fall_speed: float = 2.5

@export_category("Sound Mapping")
@export var min_volume_db: float = -18.0
@export var max_volume_db: float = 0.0
@export var min_pitch: float = 0.85
@export var max_pitch: float = 1.7

@export_category("Amplitude Pulse")
@export var pulse_enabled: bool = true
@export var pulse_freq_min: float = 2.0
@export var pulse_freq_max: float = 20.0
@export_range(0.0, 1.0) var pulse_depth_min: float = 0.5
@export_range(0.0, 1.0) var pulse_depth_max: float = 0.08

@export_category("Dodge Boost")
@export_range(0.0, 1.0) var dodge_rpm_boost: float = 0.55
@export var dodge_boost_duration: float = 0.25
@export var dodge_boost_decay_speed: float = 4.0
@export var dodge_boost_volume_db: float = 3.0

var _boost: float = 0.0
var _boost_hold_timer: float = 0.0

var volume_scale: float = 1.0
var current_rpm: float = 0.0

var _player: AudioStreamPlayer
var _pulse_phase: float = 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = bus
	add_child(_player)

	current_rpm = idle_rpm

	if engine_loop_sound:
		_player.stream = engine_loop_sound
		_player.volume_db = min_volume_db
		_player.play()


func update(accelerating: bool, speed_ratio: float, delta: float) -> void:
	_update_boost(delta)

	var target_rpm := _get_target_rpm(accelerating, speed_ratio)
	target_rpm = clampf(target_rpm + dodge_rpm_boost * _boost, 0.0, 1.0)

	var speed_factor := rpm_rise_speed if target_rpm > current_rpm else rpm_fall_speed
	current_rpm = lerpf(current_rpm, target_rpm, clampf(delta * speed_factor, 0.0, 1.0))

	var base_db := lerpf(min_volume_db, max_volume_db, current_rpm)
	var pulse_db := _get_pulse_db(delta)
	var boost_db := dodge_boost_volume_db * _boost

	_player.volume_db = base_db + pulse_db + boost_db + linear_to_db(maxf(volume_scale, 0.0001))
	_player.pitch_scale = lerpf(min_pitch, max_pitch, current_rpm)


func _update_boost(delta: float) -> void:
	if _boost_hold_timer > 0.0:
		_boost_hold_timer -= delta
		return
	_boost = move_toward(_boost, 0.0, dodge_boost_decay_speed * delta)


func _get_pulse_db(delta: float) -> float:
	if not pulse_enabled:
		return 0.0

	var freq := lerpf(pulse_freq_min, pulse_freq_max, current_rpm)
	_pulse_phase = fmod(_pulse_phase + freq * delta, 1.0)

	var wave := (sin(_pulse_phase * TAU) * 0.5) + 0.5

	var depth := lerpf(pulse_depth_min, pulse_depth_max, current_rpm)

	var depth_db := depth * 24.0
	return -((1.0 - wave) * depth_db)


func _get_target_rpm(accelerating: bool, speed_ratio: float) -> float:
	if not accelerating:
		return idle_rpm
	return lerpf(launch_rpm, max_rpm, speed_ratio)


func set_volume_scale(value: float) -> void:
	volume_scale = clampf(value, 0.0, 1.0)


func trigger_dodge_boost() -> void:
	_boost = 1.0
	_boost_hold_timer = dodge_boost_duration
