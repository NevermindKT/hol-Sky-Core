extends Control
class_name Cross_Hair

@onready var reload_bar: ProgressBar = $ReloadBar

var reload_time := 0.0
var reload_duration := 0.0

var is_reloading := false


func _ready() -> void:
	Events.reload_started.connect(start_reload)
	Events.reload_finished.connect(finish_reload)


func _process(_delta: float) -> void:
	global_position = get_viewport().get_mouse_position() - size * 0.5
	
	if is_reloading:
		reload_time += _delta
		
		reload_bar.value = (reload_time / reload_duration) * 100.0


func start_reload(duration: float):
	reload_duration = duration
	reload_time = 0.0
	is_reloading = true
	
	reload_bar.value = 0
	reload_bar.show()


func finish_reload():
	is_reloading = false
	reload_bar.value = 100
	reload_bar.hide()
	
