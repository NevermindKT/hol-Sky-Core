extends CanvasLayer
class_name HUD


@onready var top: Progress_bar = $Top
@onready var right: Ammo_counter = $Right
@onready var cross_hair_con: Cross_Hair = $CrossHairCon

func _ready() -> void:
		PauseManager.pause_state_changed.connect(_on_pause_toggle)


func _on_pause_toggle():
	visible = !PauseManager.is_paused
