extends Node3D
class_name GunMove

@export var gun: BoneAttachment3D
@export var bolt: BoneAttachment3D

@export var pitch_speed: float = 2.0
@export var min_pitch_deg: float = -22.0
@export var max_pitch_deg: float = 18.0

@export var gun_point: Marker3D
@export var muzzle_flash: Muzzle_flash

var bolt_offset: Transform3D

func _ready() -> void:
	gun.override_pose = true
	bolt.override_pose = true
	bolt_offset = gun.global_transform.affine_inverse() * bolt.global_transform


func aim_pitch(local_target: Vector3, delta: float) -> void:
	var flat_dist := Vector2(local_target.x, local_target.z).length()
	var desired_pitch := atan2(-local_target.y, flat_dist)
	desired_pitch = clamp(desired_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))

	gun.rotation.x = move_toward(gun.rotation.x, desired_pitch, pitch_speed * delta)
	bolt.global_transform = gun.global_transform * bolt_offset


func play_bolt_recoil(travel: float = 0.05, out_time: float = 0.04, in_time: float = 0.12) -> void:
	var tween := create_tween()
	tween.tween_property(bolt, "position:y", -travel, out_time)
	tween.tween_property(bolt, "position:y", 0.0, in_time)
