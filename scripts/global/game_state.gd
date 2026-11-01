extends Node
## Persistent player progress shares one snapshot with inventory and upgrades.

signal state_changed(state: State)
signal progress_reset

enum State { MAIN_MENU, BASE, DIALOGUE, RUN, SUMMARY }

var state: State = State.MAIN_MENU
var progress: Dictionary = {}


func _ready() -> void:
	load_progress()
	save_progress()


func load_progress() -> void:
	var saved: Variant = BaseInventoryManager.data.get("PlayerProgress", {})
	progress = saved if saved is Dictionary else {}
	var defaults := _defaults()
	for key in defaults:
		if not progress.has(key):
			progress[key] = defaults[key]
	BaseInventoryManager.data["PlayerProgress"] = progress


func _defaults() -> Dictionary:
	return {"started": BaseInventoryManager.had_saved_data, "intro_completed": false, "pending_arrival": -1,
		"quest_visited_bases": {"102": [], "104": []}, "story": {}}


func set_state(value: State) -> void:
	if state != value:
		state = value
		state_changed.emit(state)


func save_progress() -> void:
	BaseInventoryManager.data["PlayerProgress"] = progress
	BaseInventoryManager.save_data()


func has_progress() -> bool:
	return bool(progress.get("started", false))


func needs_intro() -> bool:
	return not bool(progress.get("intro_completed", false))


func enter_base() -> void:
	progress["started"] = true
	set_state(State.BASE)
	save_progress()


func finish_intro() -> void:
	progress["intro_completed"] = true
	save_progress()


func reset_progress() -> void:
	BaseInventoryManager.reset_save()
	load_progress()
	save_progress()
	UpgradeManager.load_saved_levels()
	progress_reset.emit()


func record_story_event(event_id: String) -> void:
	var story: Dictionary = progress["story"]
	match event_id:
		"bar.ignored":
			story["stranger_ignored"] = true
			story["water_rumor"] = true
		"prysmak.rumor", "prysmak.inactive":
			story["water_rumor"] = true
			var current_state := str(story.get("prysmak_state", ""))
			if current_state.is_empty() or (event_id == "prysmak.inactive" and current_state != "active"):
				story["prysmak_state"] = event_id.trim_prefix("prysmak.")
		"prysmak.active", "prysmak.left_active":
			story["water_rumor"] = true
			story["prysmak_state"] = "active"
			story["stranger_left"] = event_id == "prysmak.left_active"
	save_progress()
