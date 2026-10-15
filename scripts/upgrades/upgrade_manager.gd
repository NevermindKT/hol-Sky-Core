extends Node

const DATABASE_PATH := "res://resources/upgrades/upgrade_database.tres"
const UNLOCK_LEVEL := 1

#const DEBUG_UPGRADE_IDS := ["MD01", "ES01", "ES02", "BR01"]

#const DEBUG_UPGRADE_IDS := ["RF01", "BS01", "EM01", "BP01"]
const DEBUG_UPGRADE_IDS := ["LR01", "LD01", "LS01", "CC01"]


var database: UpgradeDatabase
var levels: Dictionary = {}
var _active_levels: Array[UpgradeLevel] = []

func _ready() -> void:
	database = load(DATABASE_PATH)
	InputController.debug_toggle_upgrade.connect(_on_debug_toggle_upgrade)

func _process(_delta: float) -> void:
	Engine.time_scale = get_modified(&"time_slowdown_strength", 1.0)

func get_upgrade(id: String) -> UpgradeData:
	for upgrade_data in database.upgrades:
		if upgrade_data.id == id:
			return upgrade_data
	return null

func get_level(id: String) -> int:
	return levels.get(id, 0)

func has_upgrade(id: String) -> bool:
	return get_level(id) >= 1

func get_modified(stat_id: StringName, base_value: float) -> float:
	var value := base_value

	for level in _active_levels:
		for effect in level.effects:
			value = effect.modify_stat(stat_id, value)

	for boost in BoostManager.active:
		for effect in boost.effects:
			value = effect.modify_stat(stat_id, value)

	return value

func trigger(event_id: StringName, context: Dictionary = {}) -> void:
	for level in _active_levels:
		for effect in level.effects:
			effect.on_event(event_id, context)

	for boost in BoostManager.active:
		for effect in boost.effects:
			effect.on_event(event_id, context)

func is_unlocked(upgrade_data: UpgradeData) -> bool:
	for prerequisite in upgrade_data.prerequisites:
		if get_level(prerequisite.id) < UNLOCK_LEVEL:
			return false
	return true

func is_maxed(upgrade_data: UpgradeData) -> bool:
	return get_level(upgrade_data.id) >= upgrade_data.max_level

func get_next_cost(upgrade_data: UpgradeData) -> int:
	var next := upgrade_data.get_level_data(get_level(upgrade_data.id) + 1)
	return next.cost if next else -1

func can_upgrade(upgrade_data: UpgradeData, currency: int) -> bool:
	if is_maxed(upgrade_data) or !is_unlocked(upgrade_data):
		return false
	return currency >= get_next_cost(upgrade_data)

func upgrade(upgrade_data: UpgradeData) -> void:
	if is_maxed(upgrade_data):
		return
	set_level(upgrade_data, get_level(upgrade_data.id) + 1)

func set_level(upgrade_data: UpgradeData, level: int) -> void:
	level = clampi(level, 0, upgrade_data.max_level)
	if level == 0:
		levels.erase(upgrade_data.id)
	else:
		levels[upgrade_data.id] = level
	_rebuild_active_levels()
	Events.upgrade_level_changed.emit(upgrade_data, level)

func reset() -> void:
	levels.clear()
	_rebuild_active_levels()

func _rebuild_active_levels() -> void:
	_active_levels.clear()
	for upgrade_data in database.upgrades:
		var level_data := upgrade_data.get_level_data(get_level(upgrade_data.id))
		if level_data:
			_active_levels.append(level_data)

func debug_cycle(id: String) -> void:
	var upgrade_data := get_upgrade(id)
	if upgrade_data == null:
		GameLog.print("Upgrade not found: ", id)
		return

	var next_level := (get_level(id) + 1) % (upgrade_data.max_level + 1)
	set_level(upgrade_data, next_level)
	GameLog.print("Upgrade ", id, " -> ", next_level, "/", upgrade_data.max_level)

func _on_debug_toggle_upgrade(slot: int) -> void:
	if slot < DEBUG_UPGRADE_IDS.size():
		debug_cycle(DEBUG_UPGRADE_IDS[slot])
