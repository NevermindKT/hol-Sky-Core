extends UpgradeEffect
class_name ThermalVisionEffect

func on_event(event_id: StringName, _context: Dictionary) -> void:
	if event_id == &"boost_activated":
		Events.thermal_vision_active = true
		Events.thermal_vision_changed.emit(true)
	elif event_id == &"boost_expired":
		Events.thermal_vision_active = false
		Events.thermal_vision_changed.emit(false)
