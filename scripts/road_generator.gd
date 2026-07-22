extends Node3D
class_name Road_generator


@export var road_segments: Array[RoadSegmentData]
@onready var road_manager: Road_manager = $RoadManager
@onready var road_container: Node3D = $RoadRotator/RoadContainer

var last_segment: Road_segment
var segments: Array[Road_segment] = []

var target_anchor: Marker3D

const MAX_SEGMENTS = 46
const UNLOAD_DISTANCE = 40

signal segment_spawned(segment: Road_segment)

func _ready() -> void:
	spawn_start()


func _process(delta):
	if segments.size() < MAX_SEGMENTS:
		spawn_next()
	
	if segments[0].global_position.z < -UNLOAD_DISTANCE:
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
		new_segment.transform = last_segment.transform * last_segment.anchor.transform * new_segment.origin.transform.affine_inverse()
	
	last_segment = new_segment
	segment_spawned.emit(new_segment)


func _on_player_entered_segment(segment: Road_segment):
	#_update_gizmos_()
	road_manager.select_segment(segment)


#func _update_gizmos_():
	#for segment in segments:
		#segment.set_debug_selected(false)


func spawn_start():
	spawn(road_segments[0].scene)


func spawn_next():
	var scene := pick_random_segment()
	spawn(scene)
