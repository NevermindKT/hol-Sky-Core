extends Node3D
class_name Road_generator

@export var player: Node3D
const ROAD_STRAIGHT = preload("uid://5yyn8hbn5ba5")


@onready var road_container: Node3D = $RoadContainer


var segments = []
var last_segment: Road_segment


const MAX_SEGMENTS = 16
const GENERATE_DISTANCE = 270.0


func _ready() -> void:
	spawn_next()


func _process(delta):
	if player.global_position.distance_to(last_segment.anchor.global_position) < GENERATE_DISTANCE:
		spawn_next()
	
	if segments.size() > MAX_SEGMENTS:
		segments[0].queue_free()
		segments.pop_front()


func spawn_next():
	var new_segment: Road_segment = ROAD_STRAIGHT.instantiate()
	
	segments.append(new_segment)
	road_container.add_child(new_segment)
	
	if last_segment != null:
		new_segment.global_transform = last_segment.anchor.global_transform * new_segment.origin.transform.affine_inverse()
	
	last_segment = new_segment
