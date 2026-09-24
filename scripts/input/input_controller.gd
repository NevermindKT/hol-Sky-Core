extends Node
class_name Input_Controller

var fire := false
var braking := false
var steering: float = 0.0
var accelerating := false

signal dodge

signal reload
signal next_weapon
signal previous_weapon
signal flashlight_toggle
signal headlights_toggle

signal pause_toggle

signal test_boost
signal debug_toggle_upgrade(slot: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _process(_delta):
	if Input.is_action_just_pressed("Pause"):
		pause_toggle.emit()
	
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
		
	if Input.is_action_just_pressed("toggle_flashlight"):
		flashlight_toggle.emit()

	if Input.is_action_just_pressed("toggle_headlights"):
		headlights_toggle.emit()

	if Input.is_action_just_pressed("test_boost"):
		test_boost.emit()

	for slot in 4:
		if Input.is_action_just_pressed("debug_upgrade_%d" % (slot + 1)):
			print("Start: ", slot)
			debug_toggle_upgrade.emit(slot)
