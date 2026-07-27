extends Node3D

@export var damage: float
@export var move_speed: float
@export var travel_distance: float

var start_position: Vector3

func _ready():
	start_position = global_position

func _physics_process(delta):
	global_position += -global_basis.z * move_speed * delta

	if global_position.distance_to(start_position) >= travel_distance:
		queue_free()
