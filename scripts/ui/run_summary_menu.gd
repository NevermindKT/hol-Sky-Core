extends Control
class_name Run_summary_screen

@export_category("Scenes")
@export_file("*.tscn") var menu_scene_path: String
@export_file("*.tscn") var restart_scene_path: String

@export_category("Lables")
@export var time_label: Label
@export var damage_label: Label
@export var kills_total_label: Label

@export_category("Buttons")
@export var kill_list: VBoxContainer
@export var restart_button: Button
@export var menu_button: Button


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_fill(Run_stats.last_summary)

	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.visible = not menu_scene_path.is_empty()
	menu_button.pressed.connect(_on_menu_pressed)


func _fill(summary: Dictionary) -> void:
	time_label.text = "%s" % Run_stats.format_time(summary.get("time", 0.0))
	damage_label.text = "%d" % roundi(summary.get("damage_taken", 0.0))
	kills_total_label.text = "%d" % summary.get("kills_total", 0)

	for entry in summary.get("kills", []):
		var row := Label.new()
		row.text = "%s × %d" % [entry["name"], entry["count"]]
		row.add_theme_font_size_override("font_size", 25)
		kill_list.add_child(row)


func _on_restart_pressed() -> void:
	GameFlow.change_scene(restart_scene_path)


func _on_menu_pressed() -> void:
	GameFlow.change_scene(menu_scene_path)
