extends AudioStreamPlayer
class_name WeatherAudioLayer

@export var variants: Array[AudioStream] = []
@export_range(-40.0, 24.0) var max_volume_db := 0.0
@export var fade_speed := 0.5
@export_range(0.0, 1.0) var target := 1.0

var level := 0.0


func _ready() -> void:
	if not variants.is_empty():
		stream = variants.pick_random()
	_apply()
	if stream:
		play(randf() * stream.get_length())


func _process(delta: float) -> void:
	level = move_toward(level, target, fade_speed * delta)
	_apply()


func _apply() -> void:
	volume_db = max_volume_db + linear_to_db(maxf(level, 0.0001))
	stream_paused = level <= 0.0
