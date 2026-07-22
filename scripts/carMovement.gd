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


@export_category("Strafe Physics")
@export var spring := 30.0
@export var damping := 8.0


@onready var visual_effects: Car_Visual_Effects = $Visual


func _physics_process(delta: float) -> void:
	get_input()
	process_speed(delta)
	process_strafe(delta)
	process_visuals(delta)
	
	#print("Speed: ", speed)
	#print("Lane offset: ", lane_offset)
	#print("Lateral velosity: ", lateral_velocity)


func get_input() -> void:
	steering_input = Input.get_axis("left", "right")


func process_speed(delta: float) -> void:
	if Input.is_action_pressed("accelerate"):
		var acceleration_mul = get_acceleration_multiplier()
		speed += acceleration * acceleration_mul * delta

	if Input.is_action_pressed("brake"):
		speed -= brake * delta

	speed -= drag * delta
	speed = clamp(speed, 0.0, max_speed)


func process_strafe(delta: float) -> void:
	if speed >= min_strafe_speed:
		var steering_mul = get_steering_multiplier()
		lane_offset += -steering_input * strafe_speed * steering_mul * delta

	lane_offset = clamp(
		lane_offset,
		-max_offset,
		max_offset
	)

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
