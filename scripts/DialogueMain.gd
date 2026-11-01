extends Node3D

@onready var dialogue: DialogueSystem = $DialogueSystem


func _ready() -> void:
	GameState.set_state(GameState.State.DIALOGUE)
	dialogue.branch_reached.connect(GameState.record_story_event)
	if not dialogue.dialogue_repository.has("intro_line1"):
		push_error("The base introduction is unavailable; progress was not advanced.")
		return
	var result := await dialogue.start_dialogue("intro_line1")
	if result.type != DialogueResult.Type.CANCELLED:
		GameState.finish_intro()
		GameFlow.go_to_menu()
