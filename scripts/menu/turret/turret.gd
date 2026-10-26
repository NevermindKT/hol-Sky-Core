extends Control

@onready var trees_container = $Trees


func _ready() -> void:
	Settings.language_changed.connect(refresh_turrets)
	Events.upgrade_level_changed.connect(_on_upgrade_level_changed)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	refresh_turrets()


func refresh_turrets() -> void:
	var turrets: Array = BaseInventoryManager.get_rows("Turret")
	if turrets.is_empty():
		push_warning("Массив Turret не найден или пуст в objects.json")
		return

	var turret_dict: Dictionary = {}

	for turret in turrets:
		turret_dict[int(turret.get("ID", 0))] = turret

	if trees_container:
		_update_tree_recursive(trees_container, turret_dict)


func _update_tree_recursive(parent_node: Node, turret_dict: Dictionary) -> void:
	for child in parent_node.get_children():
		if child.name.is_valid_int():
			var item_id = child.name.to_int()
			if turret_dict.has(item_id):
				_configure_object_node(child, turret_dict[item_id])

		if child.get_child_count() > 0:
			_update_tree_recursive(child, turret_dict)


func _configure_object_node(node: Node, data: Dictionary) -> void:
	if not node is Button:
		return

	var button := node as Button
	var name_text := tr(str(data.get("Name", "")))
	var upgrade_data := UpgradeManager.get_upgrade(str(data.get("UpgradeId", "")))

	if upgrade_data == null:
		button.text = name_text
		button.disabled = true
		return

	if not button.has_meta("upgrade_id"):
		button.pressed.connect(_on_turret_button_pressed.bind(button))
	button.set_meta("upgrade_id", upgrade_data.id)

	var level := UpgradeManager.get_level(upgrade_data.id)
	var level_text := tr("Рівень %d/%d") % [level, upgrade_data.max_level]

	if not UpgradeManager.is_unlocked(upgrade_data):
		button.text = tr("Заблоковано")
		button.disabled = true
	elif UpgradeManager.is_maxed(upgrade_data):
		button.text = name_text + "\n" + level_text + "\n" + tr("Максимум")
		button.disabled = false
	else:
		button.text = name_text + "\n" + level_text + "\n" + str(UpgradeManager.get_next_cost(upgrade_data))
		button.disabled = false


func _on_turret_button_pressed(button: Button) -> void:
	var upgrade_data := UpgradeManager.get_upgrade(str(button.get_meta("upgrade_id", "")))

	if upgrade_data == null or UpgradeManager.is_maxed(upgrade_data):
		return

	if not UpgradeManager.buy_level(upgrade_data):
		GameLog.print("Turret upgrade not bought: ", upgrade_data.id)


func _on_upgrade_level_changed(_upgrade_data: UpgradeData, _level: int) -> void:
	refresh_turrets()
