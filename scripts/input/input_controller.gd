extends Node
class_name Input_Controller

var fire := false
var braking := false
var steering: float = 0.0
var accelerating := false

signal dodge

signal pause

signal reload
signal next_weapon
signal previous_weapon


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _process(_delta):
	if Input.is_action_just_pressed("Pause"):
		pause.emit()
	
	if get_tree().paused:
		return
	
	fire = Input.is_action_pressed("attack")
	braking = Input.is_action_pressed("brake")
	steering = Input.get_axis("left", "right")
	accelerating = Input.is_action_pressed("accelerate")

	if Input.is_action_just_pressed("dodge"):
		dodge.emit()

	if Input.is_action_just_pressed("reload"):
		reload.emit()

	if Input.is_action_just_pressed("weapon_change_up"):
		next_weapon.emit()

	if Input.is_action_just_pressed("weapon_change_down"):
		previous_weapon.emit()
