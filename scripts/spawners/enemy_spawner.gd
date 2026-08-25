extends Node
class_name Enemy_spawner

var world: World
var road_generator: Road_generator
@export var enemy_scene: PackedScene

@export var min_gap_m := 100.0
@export var max_gap_m := 150.0
@export_range(0.0, 1.0) var spawn_chance := 0.35
@export var lateral_offset := 3.0


var _distance_accum := 0.0
var _next_threshold := 0.0


func _ready() -> void:
	if world == null or road_generator == null or enemy_scene == null:
		push_warning("EnemySpawner: не всі посилання призначені в Inspector (world / road_generator / enemy_scene).")
		return

	_next_threshold = randf_range(min_gap_m, max_gap_m)
	#Events.segment_spawned.connect(_on_segment_spawned)


func _on_segment_spawned(segment: Road_segment) -> void:
	_distance_accum += segment.length


	while _distance_accum >= _next_threshold:
		_distance_accum -= _next_threshold
		_next_threshold = randf_range(min_gap_m, max_gap_m)

		if randf() <= spawn_chance:
			_spawn_on_segment(segment)



func _spawn_on_segment(segment: Road_segment) -> void:
	var road_path := segment.get_node_or_null("RoadPath") as Path3D
	var enemy := enemy_scene.instantiate() as EnemyController
	if enemy == null:
		push_warning("EnemySpawner: enemy_scene не має скрипта EnemyController у корені.")
		return

	enemy.road_generator = road_generator
	enemy.world = world
	world.enemies.add_child(enemy)

	if road_path and road_path.curve and road_path.curve.get_baked_length() > 0.0:
		var curve := road_path.curve
		var offset := randf() * curve.get_baked_length()

		var sample := curve.sample_baked_with_rotation(offset)


		var in_segment: Transform3D = road_path.transform * sample
		var local_point: Vector3 = in_segment.origin + in_segment.basis.x * randf_range(-lateral_offset, lateral_offset)

		enemy.global_position = segment.to_global(local_point)
	else:
		var t := randf()
		var local_point: Vector3 = segment.origin.position.lerp(segment.anchor.position, t)
		local_point.x += randf_range(-lateral_offset, lateral_offset)

		enemy.global_position = segment.to_global(local_point)
