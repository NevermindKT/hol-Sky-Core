extends CharacterBody3D
class_name Car_Movement

var input: float
var speed := 0.0
var steering := 0.0
var speed_ratio := 0.0
var lane_offset := 0.0

@export var drag := 15.0
@export var brake := 50.0
@export var max_speed := 80.0
@export var acceleration := 30.0

@export var max_offset := 4.0
@export var strafe_speed := 8.0
@export var strafe_latency := 8.0
@export var min_strafe_speed := 2.0

@export var dodge_strength := 8.0

@onready var visual: Node3D = $Visual
@onready var visual_effects: Car_Visual_Effects = $Visual

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("accelerate"):
		speed += acceleration * delta
		
	if Input.is_action_pressed("brake"):
		speed -= brake * delta
	
	input = Input.get_axis("left", "right")
	
	if speed >= min_strafe_speed:
		steering = input
		lane_offset += steering * strafe_speed * delta
	
	visual_effects.process_visual_tilt(delta, steering)
	
	lane_offset = clamp(lane_offset, -max_offset, max_offset)
	
	speed -= drag * delta
	speed = clamp(speed, 0.0, max_speed)
	steering = position.x - lane_offset
	
	print("Speed: ", speed)
	print("Lane position: ", lane_offset)
	
	position.x = move_toward(position.x, lane_offset, strafe_speed * delta)
