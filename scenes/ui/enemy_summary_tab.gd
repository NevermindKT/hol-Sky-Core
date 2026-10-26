@tool
extends VBoxContainer
class_name EnemyTab

@export_category("Content")
@export var enemy_name: String = "enemy name":
	set(value):
		enemy_name = value
		_update_labels()

@export var enemy_count: String:
	set(value):
		enemy_count = value
		_update_labels()

@export var enemy_name_lbl: RichTextLabel
@export var enemy_count_lbl: RichTextLabel

func _ready() -> void:
	_update_labels()

func _update_labels():
	if not is_inside_tree():
		return

	if not is_instance_valid(enemy_name_lbl):
		return

	enemy_name_lbl.text = enemy_name
	enemy_count_lbl.text = enemy_count
