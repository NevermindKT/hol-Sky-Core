extends VBoxContainer
class_name UpgradeTree

signal upgrade_requested(upgrade_id: String)

@export var blocks: Control


func _ready() -> void:
	_connect_blocks()


func _connect_blocks() -> void:
	if not blocks:
		return

	_connect_recursive(blocks)


func _connect_recursive(parent_node: Node) -> void:
	for child in parent_node.get_children():
		if child is TreeBlock:
			if not child.upgrade_requested.is_connected(_on_block_upgrade_requested):
				child.upgrade_requested.connect(_on_block_upgrade_requested)

		_connect_recursive(child)


func refresh(turret_dict: Dictionary) -> void:
	if not blocks:
		return

	_refresh_recursive(blocks, turret_dict)


func _refresh_recursive(parent_node: Node, turret_dict: Dictionary) -> void:
	for child in parent_node.get_children():
		if child is TreeBlock:
			var object_id: int = child.object_id

			if turret_dict.has(object_id):
				child.configure(turret_dict[object_id])
			else:
				child.disabled = true
				if child.lock:
					child.lock.visible = true

		_refresh_recursive(child, turret_dict)


func _on_block_upgrade_requested(upgrade_id: String) -> void:
	upgrade_requested.emit(upgrade_id)
