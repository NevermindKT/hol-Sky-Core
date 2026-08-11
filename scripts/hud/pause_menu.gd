extends CanvasLayer
class_name Pause_Menu

@onready var pause_menu: CanvasLayer = $"."


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputController.pause.connect(_on_pause)


func _on_pause():
	PauseManager.toggle_pause()
	visible = PauseManager.is_paused
	
	if PauseManager.is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
