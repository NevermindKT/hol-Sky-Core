extends Node
class_name Road_manager

@onready var road_generator: Road_generator = $".."
@onready var road_rotator: Node3D = $"../RoadRotator"
@onready var car_movement: Car_Movement = $"../../Car"
@onready var road_container: Node3D = $"../RoadRotator/RoadContainer"

var current_segment: Road_segment
var target_angle := 0.0
var target_position := 0.0
@export var rotate_speed := 5.0
@export var position_speed := 5.0

var pending_segments: Array[Road_segment] = []
var distance_traveled := 0.0
var current_segment_end := 0.0


func _ready() -> void:
	road_generator.segment_spawned.connect(_on_segment_spawned)


func _on_segment_spawned(segment: Road_segment) -> void:
	pending_segments.append(segment)
	if current_segment == null:
		_advance_segment()


func _process(delta: float) -> void:
	var move_amount := car_movement.speed * delta
	road_container.global_position += Vector3.FORWARD * move_amount
	distance_traveled += move_amount

	if current_segment != null and distance_traveled >= current_segment_end and not pending_segments.is_empty():
		_advance_segment()

	road_rotator.rotation.y = lerp_angle(road_rotator.rotation.y, target_angle, delta * rotate_speed)
	#road_container.global_position.x = lerp(road_container.global_position.x, target_position, delta * position_speed)


func _advance_segment() -> void:
	var next_segment: Road_segment = pending_segments.pop_front()
	current_segment_end += next_segment.length
	select_segment(next_segment)


func select_segment(segment: Road_segment) -> void:
	if current_segment != null:
		current_segment.set_debug_selected(false)
	current_segment = segment
	current_segment.set_debug_selected(true)
	begin_turn()


func begin_turn() -> void:
	var anchor_in_container := current_segment.transform * current_segment.anchor.transform
	target_angle = -anchor_in_container.basis.get_euler().y
	target_position = anchor_in_container.origin.x
