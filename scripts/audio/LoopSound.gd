extends Node
class_name LoopSound

@export var stream: AudioStream
@export var bus: String = "SFX"

@export var min_volume_db: float = -80.0
@export var max_volume_db: float = 0.0

@export var min_pitch: float = 1.0
@export var max_pitch: float = 1.0

@export var attack_speed: float = 8.0
@export var release_speed: float = 1.5

var volume_scale: float = 1.0

var _player: AudioStreamPlayer
var _current_ratio: float = 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = bus
	add_child(_player)

	if stream:
		_player.stream = stream
		_player.volume_db = min_volume_db
		_player.play()


func update(ratio: float, delta: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)

	var speed_factor: float = attack_speed if ratio > _current_ratio else release_speed
	_current_ratio = lerpf(_current_ratio, ratio, clampf(delta * speed_factor, 0.0, 1.0))

	var base_db := lerpf(min_volume_db, max_volume_db, _current_ratio)
	_player.volume_db = base_db + linear_to_db(maxf(volume_scale, 0.0001))
	_player.pitch_scale = lerpf(min_pitch, max_pitch, _current_ratio)


func set_volume_scale(value: float) -> void:
	volume_scale = clampf(value, 0.0, 1.0)
