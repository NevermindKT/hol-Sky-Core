extends UpgradeEffect
class_name FlashbangEffect

func on_event(event_id: StringName, _context: Dictionary) -> void:
	if event_id == &"boost_activated":
		GrenadeSpawner.spawn_flashbang()
