extends MeshInstance3D
class_name LightningSpawnArea

func _ready():
	if !Engine.is_editor_hint():
		visible = false


func get_random_position() -> Vector3:
	var box := mesh as BoxMesh
	if box == null:
		push_error("LightningSpawnArea requires a BoxMesh.")
		return global_position

	var size := box.size

	return global_position + Vector3(
		randf_range(-size.x * 0.5, size.x * 0.5),
		randf_range(-size.y * 0.5, size.y * 0.5),
		randf_range(-size.z * 0.5, size.z * 0.5)
	)
