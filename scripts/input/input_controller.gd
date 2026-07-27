extends Node
class_name InputController

var fire := false
var braking := false
var steering: float = 0.0
var accelerating := false

signal dodge
#signal reload
#signal weapon_change

func _process(_delta):
	fire = Input.is_action_pressed("attack")
	braking = Input.is_action_pressed("brake")
	steering = Input.get_axis("left", "right")
	accelerating = Input.is_action_pressed("accelerate")
	
	if Input.is_action_just_pressed("dodge"):
		dodge.emit()
	
	#if Input.is_action_just_pressed(""):
		#wepon_change.emit()
