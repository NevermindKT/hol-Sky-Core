extends Control
class_name Run_summary_screen

@export_category("Scenes")
@export_file("*.tscn") var menu_scene_path: String
@export_file("*.tscn") var restart_scene_path: String
@export var enemy_tab_scene: PackedScene

@export_category("Labels")
@export var time_label: Label
@export var damage_label: Label
@export var kills_total_label: Label

@export_category("Buttons")
@export var kill_list: VBoxContainer
@export var restart_button: Button
@export var menu_button: Button

@export_category("Animation")
@export var animation_duration: float = 1.0
@export var row_delay: float = 0.12
@export var row_offset: float = 20.0


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_fill(Run_stats.last_summary)

	restart_button.pressed.connect(_on_restart_pressed)

	menu_button.visible = not menu_scene_path.is_empty()
	menu_button.pressed.connect(_on_menu_pressed)



func _fill(summary: Dictionary) -> void:
	time_label.text = Run_stats.format_time(0.0)
	damage_label.text = "0"
	kills_total_label.text = "0"

	for child in kill_list.get_children():
		child.queue_free()

	var kills: Array = summary.get("kills", [])

	if enemy_tab_scene == null:
		push_warning("EnemyTab scene is not assigned!")
		return

	for entry in kills:
		var row := enemy_tab_scene.instantiate() as EnemyTab

		row.enemy_name = str(entry.get("name", "Unknown"))
		row.enemy_count = "0"

		kill_list.add_child(row)

		row.modulate.a = 0.0
		row.position.y += row_offset

	_animate_number(
		time_label,
		float(summary.get("time", 0.0)),
		true
	)

	_animate_number(
		damage_label,
		float(summary.get("damage_taken", 0.0))
	)

	_animate_number(
		kills_total_label,
		float(summary.get("kills_total", 0))
	)

	for i in range(kill_list.get_child_count()):
		var row := kill_list.get_child(i) as EnemyTab
		var entry: Dictionary = kills[i]

		_animate_row(
			row,
			int(entry.get("count", 0)),
			i * row_delay
		)


func _animate_number(
	label: Label,
	target_value: float,
	is_time: bool = false
) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_method(
		func(value: float) -> void:
			if is_time:
				label.text = Run_stats.format_time(value)
			else:
				label.text = str(roundi(value)),
		0.0,
		target_value,
		animation_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _animate_row(
	row: EnemyTab,
	target_count: int,
	delay: float
) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_interval(delay)

	tween.set_parallel(true)

	tween.tween_property(
		row,
		"modulate:a",
		1.0,
		0.3
	)

	tween.tween_property(
		row,
		"position:y",
		row.position.y - row_offset,
		0.3
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.chain().tween_method(
		func(value: float) -> void:
			row.enemy_count = str(roundi(value)),
		0.0,
		float(target_count),
		0.5
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_restart_pressed() -> void:
	GameFlow.change_scene(restart_scene_path)


func _on_menu_pressed() -> void:
	GameFlow.change_scene(menu_scene_path)
