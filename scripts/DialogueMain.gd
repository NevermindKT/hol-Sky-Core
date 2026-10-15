extends Node3D

@onready var dialogue: DialogueSystem = $DialogueSystem

## Session state for the bar prototype; connect these events to a save system
## when persistent world/quest storage is introduced.
var prysmak_state := ""
var water_rumor := false
var stranger_ignored := false
var stranger_left := false

func _ready() -> void:
	dialogue.branch_reached.connect(_on_bar_event)
	await dialogue.start_dialogue("intro_line1")


func _on_bar_event(event_id: String) -> void:
	match event_id:
		"bar.ignored":
			stranger_ignored = true
			water_rumor = true
		"prysmak.rumor":
			water_rumor = true
			if prysmak_state.is_empty():
				prysmak_state = "rumor"
		"prysmak.inactive":
			water_rumor = true
			if prysmak_state != "active":
				prysmak_state = "inactive"
		"prysmak.active", "prysmak.left_active":
			water_rumor = true
			prysmak_state = "active"
			stranger_left = event_id == "prysmak.left_active"
