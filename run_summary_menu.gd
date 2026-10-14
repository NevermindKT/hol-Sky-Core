extends Control
class_name Run_summary_screen

@export_file("*.tscn") var restart_scene_path: String
@export_file("*.tscn") var menu_scene_path: String

@export var time_label: Label
@export var damage_label: Label
@export var kills_total_label: Label
#@onready var kills_list: VBoxContainer = %KillsList
#@onready var restart_button: Button = %RestartButton
#@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_fill(Run_stats.last_summary)

	#restart_button.pressed.connect(_on_restart_pressed)
	#menu_button.visible = not menu_scene_path.is_empty()
	#menu_button.pressed.connect(_on_menu_pressed)


func _fill(summary: Dictionary) -> void:
	time_label.text = "Время: %s" % Run_stats.format_time(summary.get("time", 0.0))
	damage_label.text = "Получено урона: %d" % roundi(summary.get("damage_taken", 0.0))
	kills_total_label.text = "Убито врагов: %d" % summary.get("kills_total", 0)

	for entry in summary.get("kills", []):
		var row := Label.new()
		row.text = "%s × %d" % [entry["name"], entry["count"]]
		#kills_list.add_child(row)


func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file(restart_scene_path)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(menu_scene_path)
