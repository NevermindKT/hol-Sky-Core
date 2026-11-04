extends RefCounted
class_name CarUpgradeApplicator

## Apply once per car instance, before health/HUD initialization. Earlier levels
## are prerequisites; only the highest consecutive purchased level grants effects.
static func apply(car: Car_Movement) -> void:
	if car.has_meta("car_upgrades_applied"):
		return
	car.set_meta("car_upgrades_applied", true)
	var types: Dictionary = {}
	for row in BaseInventoryManager.get_rows("Car"):
		types[str(row.get("Type", ""))] = true
	for type_name in types:
		var selected: Dictionary = {}
		var expected_level := 1
		for row in BaseInventoryManager.get_car_upgrades(type_name):
			if int(row.get("Level", 0)) != expected_level or int(row.get("Purchased", 0)) != 1:
				break
			selected = row
			expected_level += 1
		var effects: Dictionary = selected.get("Effects", {})
		for stat in effects:
			var multiplier := maxf(float(effects[stat]), 0.0)
			match stat:
				"max_health":
					car.player_status_controller.max_health *= multiplier
				"acceleration", "max_speed", "strafe_speed", "stamina_regeneration_rate", "dodge_damage":
					car.set(stat, float(car.get(stat)) * multiplier)
				"base_damage":
					car.base_damage = roundi(car.base_damage * multiplier)
				"grip_wet", "grip_flooded":
					car.set(stat, clampf(float(car.get(stat)) * multiplier, 0.0, 1.0))
				_:
					push_warning("Unknown car upgrade stat: " + str(stat))
