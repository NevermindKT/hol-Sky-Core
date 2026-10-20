@tool
extends PanelContainer
class_name Keycap

@export_category("Appearance")
@export var min_key_width: float = 40.0:
	set(value):
		min_key_width = value
		_update_keycap()

@export var key_height: float = 40.0:
	set(value):
		key_height = value
		_update_keycap()

@export var horizontal_padding: float = 8.0:
	set(value):
		horizontal_padding = value
		_update_keycap()

@export_category("Content")
@export var key_text: String = "E":
	set(value):
		key_text = value
		_update_keycap()

@export var label: Label


func _ready() -> void:
	_update_keycap()


func set_key(text: String) -> void:
	key_text = text


func _update_keycap() -> void:
	if not is_inside_tree():
		return

	if not is_instance_valid(label):
		return

	label.text = key_text

	custom_minimum_size = Vector2(
		maxf(
			min_key_width,
			label.get_combined_minimum_size().x + horizontal_padding * 2.0
		),
		key_height
	)
