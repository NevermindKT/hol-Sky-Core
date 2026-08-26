extends Node3D
class_name Road_blood_splatter


@onready var decal: Blood_decal = $BloodDecal
@onready var trigger: Area3D = $RoadBloodTrigger


func place(surface_position: Vector3, surface_normal: Vector3) -> void:
	decal.place(surface_position, surface_normal)

	if trigger:
		trigger.global_transform = decal.global_transform


func apply_random_scale(_range: Vector2) -> void:
	decal.apply_random_scale(_range)

	if trigger:
		trigger.scale = decal.scale
