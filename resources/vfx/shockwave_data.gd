extends Resource
class_name ShockwaveData

@export_group("Size")
@export var start_radius: float = 0.1
@export var end_radius: float = 2.0

@export_group("Timing")
@export var duration: float = 0.35

@export_group("Look")
@export_range(0.0, 0.3) var distortion_strength: float = 0.06
@export_range(0.1, 8.0) var fresnel_power: float = 2.5
