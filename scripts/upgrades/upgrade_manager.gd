extends Node

const DATABASE_PATH := "res://resources/upgrades/upgrade_database.tres"

#const DEBUG_UPGRADE_IDS := ["MD01", "ES01", "ES02", "BR01"]
const DEBUG_UPGRADE_IDS := ["RF01", "BS01", "EM01", "BP01"]


var database: UpgradeDatabase
var purchased: Dictionary = {}

func _ready() -> void:
	database = load(DATABASE_PATH)
	InputController.debug_toggle_upgrade.connect(_on_debug_toggle_upgrade)

func _process(_delta: float) -> void:
	Engine.time_scale = get_modified(&"time_slowdown_strength", 1.0)

func has_upgrade(id: StringName) -> bool:
	return purchased.has(id)

func get_modified(stat_id: StringName, base_value: float) -> float:
	var value := base_value

	for source in purchased.values() + BoostManager.active:
		for effect in source.effects:
			value = effect.modify_stat(stat_id, value)

	return value

func trigger(event_id: StringName, context: Dictionary = {}) -> void:
	for source in purchased.values() + BoostManager.active:
		for effect in source.effects:
			effect.on_event(event_id, context)

func can_purchase(upgrade: UpgradeData, currency: int) -> bool:
	if purchased.has(upgrade.id):
		return false

	if currency < upgrade.cost:
		return false

	for prerequisite in upgrade.prerequisites:
		if !purchased.has(prerequisite.id):
			return false

	return true

func purchase(upgrade: UpgradeData) -> void:
	purchased[upgrade.id] = upgrade
	Events.upgrade_purchased.emit(upgrade)

func debug_toggle(id: String) -> void:
	if purchased.has(id):
		purchased.erase(id)
		print("Upgrade OFF: ", id)
		return

	for upgrade in database.upgrades:
		if upgrade.id == id:
			purchased[id] = upgrade
			print("Upgrade ON: ", id)
			return

	print("Upgrade not found: ", id)

func _on_debug_toggle_upgrade(slot: int) -> void:
	if slot < DEBUG_UPGRADE_IDS.size():
		debug_toggle(DEBUG_UPGRADE_IDS[slot])
