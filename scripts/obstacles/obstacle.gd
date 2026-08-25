extends Area3D
class_name Obstacle

@export var damage_dealt: float
var hit_targets: Array[Node] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body is Car_Movement:
		return

	hit_targets.append(body)

	Events.player_take_damage.emit(damage_dealt)
	print("Player taked damage from obstacle!")


func _on_body_exited(body: Node3D) -> void:
	hit_targets.erase(body)
