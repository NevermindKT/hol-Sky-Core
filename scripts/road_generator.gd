extends Node3D
class_name Road_generator

@export var player: Node3D
@export var road_segments: Array[RoadSegmentData]


@onready var road_container: Node3D = $RoadRotator/RoadContainer


var last_segment: Road_segment
var segments: Array[Road_segment] = []

const MAX_SEGMENTS = 46
const GENERATE_DISTANCE = 280.0


func _ready() -> void:
	spawn_next()


func _process(delta):
	if player.global_position.distance_to(last_segment.anchor.global_position) < GENERATE_DISTANCE:
		spawn_next()
	
	if segments.size() > MAX_SEGMENTS:
		segments[0].queue_free()
		segments.pop_front()


func pick_random_segment() -> PackedScene:

	var total_weight := 0.0

	for data in road_segments:
		total_weight += data.weight


	var random_weight := randf_range(0.0, total_weight)

	var current_weight := 0.0

	for data in road_segments:
		current_weight += data.weight

		if random_weight <= current_weight:
			return data.scene


	return road_segments[0].scene


func spawn(scene: PackedScene):
	var new_segment: Road_segment = scene.instantiate()
	
	segments.append(new_segment)
	road_container.add_child(new_segment)
	
	if last_segment != null:
		new_segment.global_transform = last_segment.anchor.global_transform * new_segment.origin.transform.affine_inverse()
	
	last_segment = new_segment


func spawn_start():
	spawn(road_segments[0].scene)


func spawn_next():
	var scene := pick_random_segment()
	spawn(scene)
