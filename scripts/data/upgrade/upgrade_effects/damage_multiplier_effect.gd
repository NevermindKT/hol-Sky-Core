extends UpgradeEffect
class_name DamageMultiplierEffect

@export var multiplier: float = 1.0

func modify_stat(stat_id: StringName, value: float) -> float:
	if stat_id != &"weapon_damage":
		return value

	return value * multiplier
