extends Area3D
class_name Road_blood_trigger


@export var bleed_distance: float = 5.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	#print("Road_blood_trigger: body_entered -> ", body.name, " groups=", body.get_groups())

	if not body.is_in_group("Car"):
		return

	var manager := get_tree().get_first_node_in_group("blood_trail_manager")
	if manager == null:
		push_warning("Road_blood_trigger: не знайдено вузол у групі 'blood_trail_manager'.")
		return

	manager.start_bleeding(bleed_distance)
