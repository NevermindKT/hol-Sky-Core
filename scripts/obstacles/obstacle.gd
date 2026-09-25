extends Area3D
class_name Obstacle

@export var damage_dealt: float
@export var speed_loss: float = 25.0
var hit_targets: Array[Node] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body is Car_Movement:
		return
	if body.speed < 40.0:
		return

	hit_targets.append(body)

	Events.player_take_damage.emit(damage_dealt, global_position)
	body.spawn_hit_effect(global_position, 2.0)
	body.apply_impact_speed_loss(speed_loss)
	print("Player taked damage from obstacle!")


func _on_body_exited(body: Node3D) -> void:
	hit_targets.erase(body)
