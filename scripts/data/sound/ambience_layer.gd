extends Resource
class_name AmbientLayer

@export var layer_name: String = "Layer"
@export var sounds: Array[AudioStream] = []
@export var volume_db: float = 0.0
@export var pitch_variation: float = 0.05
@export var interval_min: float = 8.0
@export var interval_max: float = 20.0
@export var fade_time: float = 1.5
