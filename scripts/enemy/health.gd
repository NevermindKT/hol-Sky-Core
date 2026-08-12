extends Node
class_name Health

## Проста система здоров'я: N ударів до смерті замість миттєвого кілу.
## Не знає нічого про машину чи knockback — лише рахує урон. Хто саме
## завдає урону (машина зараз, зброя пізніше) для неї не важливо.

signal damaged(amount: float, current: float, max: float)
signal died

@export var data: HealthData

var _current: float = 0.0

func _ready() -> void:
	_current = data.max_health if data else 0.0

func take_damage(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return

	_current = max(_current - amount, 0.0)
	damaged.emit(amount, _current, data.max_health if data else 0.0)

	if _current <= 0.0:
		died.emit()

func is_dead() -> bool:
	return _current <= 0.0

func current_health() -> float:
	return _current
