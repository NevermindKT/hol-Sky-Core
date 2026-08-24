extends Area3D
class_name HurtBox

signal damaged(damage: float)

func receive_damage(damage: float) -> void:
	damaged.emit(damage)
