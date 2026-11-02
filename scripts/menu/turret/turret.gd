extends Control

@export_category("Trees")
@export var trees: HBoxContainer

@export_category("Info")
@export var info_icon: Button
@export var info_name: Label
@export var info_cost: Label
@export var purchase_btn: Button

var _selected_id := ""
var _block_group := ButtonGroup.new()


func _ready() -> void:
	Settings.language_changed.connect(refresh_turrets)
	Events.upgrade_level_changed.connect(_on_upgrade_level_changed)
	BaseInventoryManager.money_changed.connect(_on_money_changed)
	purchase_btn.pressed.connect(_on_purchase_pressed)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_connect_trees()
	refresh_turrets()
	_select_default()


func _connect_trees() -> void:
	for tree in _get_trees():
		if not tree.upgrade_selected.is_connected(_on_upgrade_selected):
			tree.upgrade_selected.connect(_on_upgrade_selected)

		for block in tree.get_blocks():
			block.toggle_mode = true
			block.button_group = _block_group


func _get_trees() -> Array[UpgradeTree]:
	var result: Array[UpgradeTree] = []

	for tree in trees.get_children():
		if tree is UpgradeTree:
			result.append(tree)

	return result


func _get_all_blocks() -> Array[TreeBlock]:
	var result: Array[TreeBlock] = []

	for tree in _get_trees():
		result.append_array(tree.get_blocks())

	return result


func refresh_turrets() -> void:
	var turrets: Array = BaseInventoryManager.get_rows("Turret")

	if turrets.is_empty():
		push_warning("Массив Turret не найден или пуст в objects.json")
		return

	var turret_dict: Dictionary = {}

	for turret in turrets:
		turret_dict[int(turret.get("ID", 0))] = turret

	for tree in _get_trees():
		tree.refresh(turret_dict)

	_update_info()


func _select_default() -> void:
	var first: TreeBlock = null

	for block in _get_all_blocks():
		if block.disabled or block.upgrade_id.is_empty():
			continue
		if first == null or block.object_id < first.object_id:
			first = block

	if first:
		first.button_pressed = true
		_on_upgrade_selected(first.upgrade_id)


func _find_block(upgrade_id: String) -> TreeBlock:
	for block in _get_all_blocks():
		if block.upgrade_id == upgrade_id:
			return block

	return null


func _update_info() -> void:
	var upgrade_data := UpgradeManager.get_upgrade(_selected_id)
	var block := _find_block(_selected_id)

	if upgrade_data == null or block == null:
		info_icon.icon = null
		info_name.text = ""
		info_cost.text = ""
		purchase_btn.disabled = true
		return

	info_icon.icon = block.icon
	info_name.text = "%s (%d/%d)" % [
		tr(block.title),
		UpgradeManager.get_level(_selected_id),
		upgrade_data.max_level
	]

	if UpgradeManager.is_maxed(upgrade_data):
		info_cost.text = tr("Максимум")
		purchase_btn.disabled = true
		return

	var cost := UpgradeManager.get_next_cost(upgrade_data)
	info_cost.text = str(cost)
	purchase_btn.disabled = (
		not UpgradeManager.is_unlocked(upgrade_data)
		or cost > BaseInventoryManager.get_player_money()
	)


func _on_upgrade_selected(upgrade_id: String) -> void:
	_selected_id = upgrade_id
	_update_info()


func _on_purchase_pressed() -> void:
	var upgrade_data := UpgradeManager.get_upgrade(_selected_id)

	if upgrade_data == null or UpgradeManager.is_maxed(upgrade_data):
		return

	if not UpgradeManager.buy_level(upgrade_data):
		GameLog.print("Turret upgrade not bought: ", _selected_id)


func _on_money_changed(_amount: int) -> void:
	_update_info()


func _on_upgrade_level_changed(_upgrade_data: UpgradeData, _level: int) -> void:
	refresh_turrets()
