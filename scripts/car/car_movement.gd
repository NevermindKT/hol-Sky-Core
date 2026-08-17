extends CharacterBody3D
class_name Car_Movement

var speed := 0.0
var lane_offset := 0.0
var lateral_velocity := 0.0
var last_lateral_velocity := 0.0


var steering_input := 0.0


@export_category("Movement")
@export var drag := 15.0
@export var brake := 50.0
@export var max_speed := 80.0
@export var acceleration := 30.0
@export var acceleration_curve: Curve


@export_category("Strafe")
@export var max_offset := 4.0
@export var strafe_speed := 8.0
@export var steering_curve: Curve
@export var min_strafe_speed := 2.0


@export_category("Dodge")
@export var dodge_force := 12.0
@export var dodge_distance := 2.0


@export_category("Strafe Physics")
@export var spring := 30.0
@export var damping := 8.0


@export_category("Hit")
@export var base_damage := 15


@export_category("Exports")
@export var player_cam: Camera3D

@onready var cam_pivot: Node3D = $CamPivot
@onready var inventory: Inventory = $Inventory
@onready var weapon_pivot: Node3D = $Visual/WeaponPivot
@onready var visual_effects: Car_Visual_Effects = $Visual
@onready var weapon_controller: Weapon_controller = $WeaponController
@onready var player_status_controller: Player_Status_Controller = $PlayerStatusController


func _ready() -> void:
	InputController.dodge.connect(dodge)


func _physics_process(delta: float) -> void:
	get_input()
	process_speed(delta)
	process_strafe(delta)
	process_visuals(delta)
	process_enemies_hits()
	
	#print("Speed: ", speed)
	#print("Lane offset: ", lane_offset)
	#print("Lateral velosity: ", lateral_velocity)


func process_enemies_hits() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()

		if collider.is_in_group("Enemy"):
			var hit_data := create_hit_data(collision.get_position(), collision.get_normal())
			collider.on_car_hit(hit_data)


func create_hit_data(contact_point: Vector3, contact_normal: Vector3) -> HitData:
	var car_velocity := -global_transform.basis.z * speed
	return HitData.new(self, car_velocity, contact_point, contact_normal, base_damage)


func get_input() -> void:
	steering_input = InputController.steering


func process_speed(delta: float) -> void:
	if InputController.accelerating:
		var acceleration_mul = get_acceleration_multiplier()
		speed += acceleration * acceleration_mul * delta

	if InputController.braking:
		speed -= brake * delta

	speed -= drag * delta
	speed = clamp(speed, 0.0, max_speed)


func process_strafe(delta: float) -> void:
	if speed >= min_strafe_speed:
		var steering_mul = get_steering_multiplier()
		lane_offset += steering_input * strafe_speed * steering_mul * delta

	lane_offset = clamp_offset()

	var error := lane_offset - position.x

	lateral_velocity += error * spring * delta
	lateral_velocity *= exp(-damping * delta)

	position.x += lateral_velocity * delta


func process_visuals(delta: float) -> void:
	visual_effects.process_visual_tilt(delta, lateral_velocity)


func get_speed_ratio() -> float:
	return clampf(speed / max_speed, 0.0, 1.0)


func get_acceleration_multiplier() -> float:
	return acceleration_curve.sample_baked(get_speed_ratio())


func get_steering_multiplier() -> float:
	return steering_curve.sample_baked(get_speed_ratio())


func dodge() -> void:
	if steering_input == 0.0:
		return
	
	var direction = sign(steering_input)
	
	lane_offset += direction * dodge_distance
	lane_offset = clamp_offset()


func clamp_offset() -> float:
	return clamp(lane_offset, -max_offset, max_offset)
