extends Node
class_name Road_manager


@onready var car: Car_Movement = $"../../Car"
@onready var road_rotator: Node3D = $"../RoadRotator"
@onready var road_container: Node3D = $"../RoadRotator/RoadContainer"


func _process(delta: float) -> void:
	road_container.global_position += Vector3.FORWARD * car.speed * delta
	
	if Input.is_action_pressed("WorldRevolveLeft"):
		road_rotator.rotation.y -= 0.01
	
	if Input.is_action_pressed("WorldRevolveRight"):
		road_rotator.rotation.y += 0.01
