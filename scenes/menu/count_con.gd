extends Panel

@export var label: Label
@export var panel: PanelContainer

func set_text(new_text: String) -> void:
	label.text = new_text
	await get_tree().process_frame
	panel.size = panel.get_combined_minimum_size()
