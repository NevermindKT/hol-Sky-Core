extends UpgradeEffect
class_name ScreenEffectToggleEffect

@export var effect_id: StringName

func on_event(event_id: StringName, _context: Dictionary) -> void:
	if event_id == &"boost_activated":
		ScreenEffects.show_effect(effect_id)
	elif event_id == &"boost_expired":
		ScreenEffects.hide_effect(effect_id)
