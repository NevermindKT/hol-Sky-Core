extends Node3D
class_name Road_segment

@export var anchor: Marker3D
@export var origin: Marker3D

@export var weight := 1.0
@export var segment_type: RoadType.Type

var polygon: CSGPolygon3D

var length: float

func _ready() -> void:
	assert(origin != null, "Origin missing in " + name)
	assert(anchor != null, "Anchor missing in " + name)
	length = origin.position.distance_to(anchor.position)
