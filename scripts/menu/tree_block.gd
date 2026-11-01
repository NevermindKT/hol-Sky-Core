@tool
extends Button
class_name TreeBlock

signal upgrade_requested(upgrade_id: String)

@export_category("Settings")
@export var object_id: int = 0
@export var lock: TextureRect

var _upgrade_id: String = ""


func _ready() -> void:
	pressed.connect(_on_pressed)


func configure(data: Dictionary) -> void:
	var upgrade_data := UpgradeManager.get_upgrade(
		str(data.get("UpgradeId", ""))
	)

	if upgrade_data == null:
		_upgrade_id = ""
		disabled = true
		if lock:
			lock.visible = true
		return

	_upgrade_id = upgrade_data.id

	refresh_state(upgrade_data)


func refresh_state(upgrade_data: UpgradeData = null) -> void:
	if upgrade_data == null:
		upgrade_data = UpgradeManager.get_upgrade(_upgrade_id)

	if upgrade_data == null:
		return

	var unlocked := UpgradeManager.is_unlocked(upgrade_data)
	var maxed := UpgradeManager.is_maxed(upgrade_data)

	disabled = not unlocked

	if lock:
		lock.visible = not unlocked

	tooltip_text = "%s\n%s/%s" % [
		tr("Рівень"),
		UpgradeManager.get_level(_upgrade_id),
		upgrade_data.max_level
	]

	if maxed:
		tooltip_text += "\n" + tr("Максимум")


func _on_pressed() -> void:
	if _upgrade_id.is_empty():
		return

	var upgrade_data := UpgradeManager.get_upgrade(_upgrade_id)

	if upgrade_data == null:
		return

	if UpgradeManager.is_maxed(upgrade_data):
		return

	upgrade_requested.emit(_upgrade_id)
