extends Node

@onready var car: Car_Movement = $"../../Car"
@onready var road_container: Node3D = $"../RoadContainer"

func _process(delta: float) -> void:
	road_container.global_position += Vector3.FORWARD * car.speed * delta
