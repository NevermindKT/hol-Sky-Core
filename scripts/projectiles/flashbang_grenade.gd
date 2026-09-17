extends Node3D
class_name FlashbangGrenade

signal detonated

@export var throw_speed := 14.0
@export var gravity_accel := 9.8
@export var fuse_time := 1.2
@export var spin_speed := 6.0
@export var flash_effect: Muzzle_flash

var velocity: Vector3
var angular_velocity: Vector3

func _ready() -> void:
	angular_velocity = Vector3(
		randf_range(-spin_speed, spin_speed),
		randf_range(-spin_speed, spin_speed),
		randf_range(-spin_speed, spin_speed)
	)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	velocity.y -= gravity_accel * delta

	rotate_x(angular_velocity.x * delta)
	rotate_y(angular_velocity.y * delta)
	rotate_z(angular_velocity.z * delta)

	fuse_time -= delta
	if fuse_time <= 0.0:
		detonate()

func detonate() -> void:
	detonated.emit()
	flash_effect.reparent(get_parent())
	flash_effect.play(true)
	queue_free()
