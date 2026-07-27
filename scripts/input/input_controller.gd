extends Node
class_name InputController

var steering: float = 0.0
var accelerating := false
var braking := false

func _process(_delta):
	steering = Input.get_axis("left", "right")
	braking = Input.is_action_pressed("brake")
	accelerating = Input.is_action_pressed("accelerate")
