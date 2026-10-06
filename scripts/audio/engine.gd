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

var volume_scale: float = 1.0

var current_rpm: float = 0.0
var _player: AudioStreamPlayer


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
	var target_rpm := _get_target_rpm(accelerating, speed_ratio)

	var rise_speed := rpm_rise_speed
	var fall_speed := rpm_fall_speed
	var speed_factor := rise_speed if target_rpm > current_rpm else fall_speed

	current_rpm = lerpf(current_rpm, target_rpm, clampf(delta * speed_factor, 0.0, 1.0))

	_player.volume_db = lerpf(min_volume_db, max_volume_db, current_rpm) + linear_to_db(maxf(volume_scale, 0.0001))
	_player.pitch_scale = lerpf(min_pitch, max_pitch, current_rpm)


func _get_target_rpm(accelerating: bool, speed_ratio: float) -> float:
	if not accelerating:
		return idle_rpm

	return lerpf(launch_rpm, max_rpm, speed_ratio)


func set_volume_scale(value: float) -> void:
	volume_scale = clampf(value, 0.0, 1.0)
