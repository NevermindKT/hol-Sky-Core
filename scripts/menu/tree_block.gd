@tool
extends Button
class_name TreeBlock

signal selected(upgrade_id: String)

const NOT_OWNED_ICON_COLOR := Color(1, 1, 1, 0.45)
const ICON_COLORS: Array[StringName] = [
	&"icon_normal_color",
	&"icon_hover_color",
	&"icon_pressed_color",
	&"icon_hover_pressed_color",
	&"icon_focus_color",
]

@export_category("Settings")
@export var object_id: int = 0
@export var lock: TextureRect

var upgrade_id: String = ""
var title: String = ""
var level := 0


func _ready() -> void:
	pressed.connect(_on_pressed)


func configure(data: Dictionary) -> void:
	var upgrade_data := UpgradeManager.get_upgrade(
		str(data.get("UpgradeId", ""))
	)
	title = str(data.get("Name", ""))

	if upgrade_data == null:
		upgrade_id = ""
		level = 0
		disabled = true
		if lock:
			lock.visible = true
		return

	upgrade_id = upgrade_data.id

	refresh_state(upgrade_data)


func refresh_state(upgrade_data: UpgradeData = null) -> void:
	if upgrade_data == null:
		upgrade_data = UpgradeManager.get_upgrade(upgrade_id)

	if upgrade_data == null:
		return

	var unlocked := UpgradeManager.is_unlocked(upgrade_data)
	level = UpgradeManager.get_level(upgrade_id)

	disabled = not unlocked

	if lock:
		lock.visible = not unlocked

	for color_name in ICON_COLORS:
		if level > 0:
			remove_theme_color_override(color_name)
		else:
			add_theme_color_override(color_name, NOT_OWNED_ICON_COLOR)

	tooltip_text = "%s\n%s" % [
		tr(title),
		tr("Рівень %d/%d") % [level, upgrade_data.max_level]
	]

	if UpgradeManager.is_maxed(upgrade_data):
		tooltip_text += "\n" + tr("Максимум")


func _on_pressed() -> void:
	if upgrade_id.is_empty():
		return

	selected.emit(upgrade_id)
