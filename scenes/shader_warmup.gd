extends Node3D

signal completed

@export_range(1, 60) var render_frames := 8

@export var camera: Camera3D
@export var car: Car_Movement
@export var blood_hit: BloodCarHit
@export var enemy: Encounter_Enemy
@export var mock_hit_point: Marker3D
@export var stroke_point: Marker3D

@export var blood_stroke_scene: PackedScene 

func _ready() -> void:
	camera.current = true

	var hit_position := car.global_position + mock_hit_point.transform.origin
	var hit_direction := Vector3.FORWARD

	blood_hit.play(
		hit_position,
		hit_direction,
		car.speed,
		car
	)

	_warmup_blood_stroke()
	enemy.warmup_effects()

	for i in render_frames:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

	completed.emit()


func _warmup_blood_stroke() -> void:
	var stroke: Tire_trail_stroke = blood_stroke_scene.instantiate()
	add_child(stroke)
	stroke.global_transform = stroke_point.global_transform

	for i in 10:
		stroke.add_point(Vector3(0.0, 0.0, -i * 0.3))
