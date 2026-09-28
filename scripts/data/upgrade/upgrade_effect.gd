extends Resource
class_name UpgradeEffect

func modify_stat(_stat_id: StringName, value: float) -> float:
	return value

func can_activate() -> bool:
	return true

func on_event(_event_id: StringName, _context: Dictionary) -> void:
	pass
