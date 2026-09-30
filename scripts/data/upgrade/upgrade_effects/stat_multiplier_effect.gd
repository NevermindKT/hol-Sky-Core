extends UpgradeEffect
class_name StatMultiplierEffect

enum Operation {
	MULTIPLY,
	ADD,
}

@export var stat_id: StringName
@export var operation: Operation = Operation.MULTIPLY
@export var multiplier: float = 1.0

func modify_stat(_stat_id: StringName, value: float) -> float:
	if _stat_id != self.stat_id:
		return value

	match operation:
		Operation.ADD:
			return value + multiplier
		_:
			return value * multiplier
