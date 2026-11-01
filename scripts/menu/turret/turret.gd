extends Control

@export_category("Trees")
@export var trees: HBoxContainer


func _ready() -> void:
	Settings.language_changed.connect(refresh_turrets)
	Events.upgrade_level_changed.connect(_on_upgrade_level_changed)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_connect_trees()
	refresh_turrets()


func _connect_trees() -> void:
	for tree in trees.get_children():
		if tree is UpgradeTree:
			if not tree.upgrade_requested.is_connected(_on_upgrade_requested):
				tree.upgrade_requested.connect(_on_upgrade_requested)


func refresh_turrets() -> void:
	var turrets: Array = BaseInventoryManager.get_rows("Turret")

	if turrets.is_empty():
		push_warning("Массив Turret не найден или пуст в objects.json")
		return

	var turret_dict: Dictionary = {}

	for turret in turrets:
		turret_dict[int(turret.get("ID", 0))] = turret

	for tree in trees.get_children():
		if tree is UpgradeTree:
			tree.refresh(turret_dict)


func _on_upgrade_requested(upgrade_id: String) -> void:
	var upgrade_data := UpgradeManager.get_upgrade(upgrade_id)

	if upgrade_data == null or UpgradeManager.is_maxed(upgrade_data):
		return

	if not UpgradeManager.buy_level(upgrade_data):
		GameLog.print("Turret upgrade not bought: ", upgrade_id)


func _on_upgrade_level_changed(_upgrade_data: UpgradeData, _level: int) -> void:
	refresh_turrets()
