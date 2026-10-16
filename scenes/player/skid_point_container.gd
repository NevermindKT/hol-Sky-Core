extends Node3D

@export var visual: Car_Visual_Effects

func _physics_process(_delta: float) -> void:
	rotation.y = visual.rotation.y
