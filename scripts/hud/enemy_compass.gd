extends Control
class_name Enemy_Compass

@export var encounter: Enemy_Encounter
@export var marker_scene: PackedScene

@export var world_width := 20.0

var markers: Dictionary = {}

func _process(_delta: float) -> void:
	if encounter == null:
		return
	
	update_markers()
	
	for marker in markers.values():
		if is_instance_valid(marker.enemy):
			update_marker(marker)


func update_markers() -> void:
	for enemy in encounter.enemies:
		if not markers.has(enemy):
			var marker := marker_scene.instantiate() as Enemy_Marker
			
			add_child(marker)
			
			marker.enemy = enemy
			markers[enemy] = marker
	
	for enemy in markers.keys():
		if not is_instance_valid(enemy):
			var marker: Enemy_Marker = markers[enemy]
			
			marker.queue_free()
			markers.erase(enemy)


func update_marker(marker: Enemy_Marker) -> void:
	var relative_x := (
		marker.enemy.global_position.x -
		encounter.player.global_position.x
	)

	var normalized := relative_x / world_width
	var screen_x := size.x * 0.5 + normalized * size.x * 0.5

	screen_x = clamp(
		screen_x,
		0.0,
		size.x
	)

	marker.position.x = screen_x
