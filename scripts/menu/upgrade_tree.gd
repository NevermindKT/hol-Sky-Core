extends VBoxContainer
class_name UpgradeTree

signal upgrade_selected(upgrade_id: String)

@export var blocks: Control
@export var connections: Control
@export var title: RichTextLabel


func _ready() -> void:
	for block in get_blocks():
		if not block.selected.is_connected(_on_block_selected):
			block.selected.connect(_on_block_selected)


func get_blocks() -> Array[TreeBlock]:
	var result: Array[TreeBlock] = []

	if blocks:
		for child in blocks.find_children("*", "TreeBlock", true, false):
			result.append(child)

	return result


func refresh(turret_dict: Dictionary) -> void:
	var branch_name := ""

	for block in get_blocks():
		if turret_dict.has(block.object_id):
			block.configure(turret_dict[block.object_id])
		else:
			block.disabled = true
			if block.lock:
				block.lock.visible = true

		var upgrade_data := UpgradeManager.get_upgrade(block.upgrade_id)

		if branch_name.is_empty() and upgrade_data and upgrade_data.branch:
			branch_name = upgrade_data.branch.display_name

	if title and not branch_name.is_empty():
		title.text = tr(branch_name)

	if connections:
		for connection in connections.get_children():
			if connection is TreeConnection and connection.from_block:
				connection.set_active(connection.from_block.level > 0)


func _on_block_selected(upgrade_id: String) -> void:
	upgrade_selected.emit(upgrade_id)
