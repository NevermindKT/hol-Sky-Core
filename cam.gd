extends Camera3D

@onready var cam_pivot: Node3D = $"../Car/CamPivot"

@export var cam_latency := 2.0

func _physics_process(delta):
	var pos = global_position
	pos.x = lerp(pos.x, cam_pivot.global_position.x, cam_latency * delta)
	global_position = pos
