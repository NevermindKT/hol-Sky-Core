extends Node

const DATABASE_PATH := "res://resources/upgrades/upgrade_database.tres"

var database: UpgradeDatabase
var purchased: Dictionary = {}

func _ready() -> void:
	database = load(DATABASE_PATH)

func has_upgrade(id: StringName) -> bool:
	return purchased.has(id)

func get_modified(stat_id: StringName, base_value: float) -> float:
	var value := base_value

	for upgrade in purchased.values():
		for effect in upgrade.effects:
			value = effect.modify_stat(stat_id, value)

	return value

func trigger(event_id: StringName, context: Dictionary = {}) -> void:
	for upgrade in purchased.values():
		for effect in upgrade.effects:
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
