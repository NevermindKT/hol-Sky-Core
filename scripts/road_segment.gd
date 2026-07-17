extends Node3D
class_name Road_segment

@onready var anchor: Marker3D = $Anchor
@onready var origin: Marker3D = $Origin

@export var weight := 1.0
@export var segment_type: RoadTypes.Type
