extends UpgradeEffect
class_name StatMultiplierEffect

@export var stat_id: StringName
@export var multiplier: float = 1.0

func modify_stat(stat_id: StringName, value: float) -> float:
	if stat_id != self.stat_id:
		return value

	return value * multiplier
