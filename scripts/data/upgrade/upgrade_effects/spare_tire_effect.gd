extends UpgradeEffect
class_name SpareTireEffect

func can_activate() -> bool:
	return Wheel_Loss_Controller.current != null and Wheel_Loss_Controller.current.has_missing_wheel()

func on_event(event_id: StringName, _context: Dictionary) -> void:
	if event_id == &"boost_activated" and Wheel_Loss_Controller.current != null:
		Wheel_Loss_Controller.current.repair()
