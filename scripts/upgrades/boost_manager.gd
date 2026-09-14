extends Node

const TEST_BOOST_PATH := "res://resources/upgrades/boosts/nitro.tres"

var owned: Dictionary = {}
var active: Array[BoostData] = []
var _time_left: Dictionary = {}

func add_owned(boost: BoostData, amount: int = 1) -> void:
	owned[boost.id] = owned.get(boost.id, 0) + amount

func can_activate(boost: BoostData) -> bool:
	return owned.get(boost.id, 0) > 0

func activate(boost: BoostData) -> void:
	if !can_activate(boost):
		return

	owned[boost.id] -= 1

	if boost.duration <= 0.0:
		for effect in boost.effects:
			effect.on_event(&"boost_activated", {"boost": boost})
		return

	if !active.has(boost):
		active.append(boost)

	_time_left[boost] = boost.duration

	for effect in boost.effects:
		effect.on_event(&"boost_activated", {"boost": boost})

func activate_test_boost() -> void:
	var boost := load(TEST_BOOST_PATH) as BoostData
	add_owned(boost)
	activate(boost)

func _process(delta: float) -> void:
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta

	for boost in active.duplicate():
		_time_left[boost] -= real_delta

		if _time_left[boost] <= 0.0:
			active.erase(boost)
			_time_left.erase(boost)

			for effect in boost.effects:
				effect.on_event(&"boost_expired", {"boost": boost})
