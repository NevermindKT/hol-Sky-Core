extends Area3D
class_name HurtBox

signal hit(hit_position: Vector3, direction: Vector3, damage: float)

func receive_hit(hit_position: Vector3, direction: Vector3, damage: float) -> void:
	hit.emit(hit_position, direction, damage)
