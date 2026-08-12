extends CanvasLayer
class_name Pause_Menu

@onready var continue_btn: Button = $Menu/ContinueBtn
@onready var options_btn: Button = $Menu/OptionsBtn
@onready var exit_btn: Button = $Menu/ExitBtn

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	PauseManager.pause_state_changed.connect(_on_pause_state_changed)
	continue_btn.pressed.connect(_on_continue_pressed)


func _on_pause_state_changed():
	check_visible()


func _on_continue_pressed():
	PauseManager.set_paused(false)
	check_visible()


func check_visible():
	visible = PauseManager.is_paused
	
	if PauseManager.is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
