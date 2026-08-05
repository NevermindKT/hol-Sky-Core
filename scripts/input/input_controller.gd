extends Node
class_name InputController

var fire := false
var braking := false
var steering: float = 0.0
var accelerating := false

signal dodge
signal reload
signal weapon_change_up
signal weapon_change_down

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _process(_delta):
	fire = Input.is_action_pressed("attack")
	braking = Input.is_action_pressed("brake")
	steering = Input.get_axis("left", "right")
	accelerating = Input.is_action_pressed("accelerate")
	
	if Input.is_action_just_pressed("dodge"):
		dodge.emit()
	
	if Input.is_action_just_pressed("reload"):
		reload.emit()
	
	if Input.is_action_just_pressed("weapon_change_up"):
		weapon_change_up.emit()
	
	if Input.is_action_just_pressed("weapon_change_down"):
		weapon_change_down.emit()
