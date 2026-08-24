extends Node3D
class_name Projectile

var damage: float
var gravity_scale := 1.0
var projectile_speed: float
var projectile_distance: float

const GRAVITY := Vector3.DOWN * 9.81

var velocity: Vector3
var start_position: Vector3

@onready var hit_box: Area3D = $HitBox


func _ready() -> void:
	hit_box.area_entered.connect(_on_hit_box_area_entered)


func initialize(data: WeaponData, direction: Vector3):
	start_position = global_position
	
	damage = data.damage
	gravity_scale = data.gravity_scale
	projectile_speed = data.projectile_speed
	projectile_distance = data.projectile_distance
	velocity = direction.normalized() * projectile_speed


func _physics_process(delta):
	velocity += GRAVITY * gravity_scale * delta
	global_position += velocity * delta

	if global_position.distance_to(start_position) >= projectile_distance:
		queue_free()


func _on_hit_box_area_entered(area: Area3D) -> void:
	if area is HurtBox:
		area.receive_damage(damage)
		queue_free()
