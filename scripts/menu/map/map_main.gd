extends Control

# --- СУЩЕСТВУЮЩИЕ ПЕРЕМЕННЫЕ КАРТЫ И БАЗ ---
@export_category("Map")
@export var map_node: Panel
@export var lis1_node: Control 
@export var lis1_roads: Control 
@export var lis1_markers: Control 
@export var active_lis1: Button

@export_category("Base")
@export var BasePanel: Panel
@export var base_num_label: Label
@export var base_name_label: Label
@export var hardness_label: Label
@export var monsters_label: Label
@export var description_label: Label
@export var play_button: Button


@export var close_button: Button
@export var name_label: Label

# --- ПЕРЕМЕННЫЕ СИСТЕМЫ КВЕСТОВ ---
@export_category("Quest")
@export var quests_panel: Panel
@export var quests_open_close_btn: Button
@export var lis1_quest_category: Button
@export var lis1_arrow: Control
@export var lis1_quests_vbox: VBoxContainer

@export var quest_nodes: Array[Button] = []
@export var marker_nodes: Array[Button] = []

@export var quest3_timer_node: Timer

var quests_hidden_pos: Vector2 = Vector2(1920.0, 226.0)
var quests_visible_pos: Vector2 = Vector2(1499.0, 226.0)
var quests_is_open: bool = false
var lis1_quests_open: bool = false

# Словарь для отслеживания уже посещенных баз в квестах 102 и 104 (без повторов)
var quest_visited_bases: Dictionary = {
	102: [],
	104: []
}

# Траектории панели баз
var hidden_pos: Vector2 = Vector2(-601.0, 171.0)
var base_visible_pos: Vector2 = Vector2(-27.0, 171.0)

var default_map_pos: Vector2 = Vector2(207.0, 109.0)
var default_map_scale: Vector2 = Vector2(1.0, 1.0)
var zoomed_map_pos: Vector2 = Vector2(481.0, -21.0)
var zoomed_map_scale: Vector2 = Vector2(1.0, 1.0)

var default_lis1_scale: Vector2 = Vector2(1.0, 1.0)
var zoomed_lis1_scale: Vector2 = Vector2(1.1, 1.1)

var current_base_id: int = -1
var is_animating: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if map_node:
		map_node.position = default_map_pos
		map_node.scale = default_map_scale

	if lis1_node:
		lis1_node.scale = default_lis1_scale

	if lis1_roads:
		lis1_roads.visible = false
		lis1_roads.modulate.a = 0.0

	if lis1_markers:
		lis1_markers.visible = false
		lis1_markers.modulate.a = 0.0

	if BasePanel:
		BasePanel.position = hidden_pos

	if close_button:
		close_button.visible = false
		close_button.pressed.connect(_on_close_map_pressed)

	if play_button:
		play_button.pressed.connect(_on_base_play_pressed)

	if name_label:
		name_label.text = ""

	if quests_panel:
		quests_panel.position = quests_hidden_pos
	if quests_open_close_btn:
		quests_open_close_btn.pressed.connect(_on_quests_open_close_pressed)

	if lis1_quest_category:
		lis1_quest_category.pressed.connect(_on_lis1_quest_category_pressed)

	if active_lis1:
		active_lis1.pressed.connect(_on_active_lis1_pressed)

	# Настраиваем узел Timer (one_shot, подключение сигнала)
	if quest3_timer_node:
		quest3_timer_node.one_shot = true
		if not quest3_timer_node.timeout.is_connected(_on_quest3_timeout):
			quest3_timer_node.timeout.connect(_on_quest3_timeout)

	for m in marker_nodes:
		if m:
			m.pressed.connect(func(): _on_marker_pressed(m))

	if lis1_roads:
		for road_node in lis1_roads.get_children():
			if road_node is BaseButton:
				road_node.pressed.connect(func(): _on_road_pressed(road_node))

	_load_current_active_base()
	_check_and_update_quests_logic()

func _process(_delta: float) -> void:
	# Если панель квестов открыта и таймер идет, плавно обновляем отображение секунд
	if lis1_quests_open and quest3_timer_node and not quest3_timer_node.is_stopped():
		var prog_lbl = quest_nodes[2].get_node_or_null("Progress") as Label
		if prog_lbl:
			var rem_time = int(ceil(quest3_timer_node.time_left))
			prog_lbl.text = "(Таймер: %d сек.)" % rem_time



func _load_current_active_base() -> void:
	var bases: Array = BaseInventoryManager.get_rows("Bases")

	for row in bases:
		if int(row.get("ISActive", 0)) == 1:
			current_base_id = int(row.get("ID", -1))
			break

	_update_markers_scale()
	_update_roads_appearance()
	_check_and_update_quests_logic()

# --- ЛОГИКА ПРОВЕРКИ И ВЫПОЛНЕНИЯ КВЕСТОВ ---

func _check_and_update_quests_logic() -> void:
	for q_btn in quest_nodes:
		if not q_btn:
			continue

		var q_id := int(q_btn.text.strip_edges())
		if q_id == 0:
			continue

		var quest = BaseInventoryManager.find_row("Quests", "ID", q_id)
		if quest.is_empty():
			continue

		var unlocked := int(quest.get("Unlocked", 0))
		var have := int(quest.get("Have", 0))
		var need := int(quest.get("Need", 1))

		if unlocked != 1:
			continue

		var calculated_have := have

		# Квесты 101 и 105: нужна активная база 1004.
		if q_id == 101 or q_id == 105:
			var base = BaseInventoryManager.find_row("Bases", "ID", 1004)

			if not base.is_empty() and int(base.get("ISActive", 0)) == 1:
				calculated_have = 1
			else:
				calculated_have = 0

			BaseInventoryManager.update_row(
				"Quests", "ID", q_id, {"Have": calculated_have}
			)

		# Квест 103: таймер.
		elif q_id == 103:
			if have < need:
				if quest3_timer_node \
				and quest3_timer_node.is_stopped() \
				and quest3_timer_node.time_left == 0.0:
					quest3_timer_node.wait_time = float(need)
					quest3_timer_node.start()
			else:
				calculated_have = need

				BaseInventoryManager.update_row(
					"Quests", "ID", q_id, {"Have": calculated_have}
				)

		if calculated_have >= need:
			BaseInventoryManager.update_row(
				"Quests", "ID", q_id, {"Unlocked": 2}
			)

			match q_id:
				101:
					BaseInventoryManager.update_row(
						"Quests", "ID", 102, {"Unlocked": 1}
					)
				102:
					BaseInventoryManager.update_row(
						"Quests", "ID", 103, {"Unlocked": 1}
					)
				103:
					BaseInventoryManager.update_row(
						"Quests", "ID", 104, {"Unlocked": 1}
					)
				104:
					BaseInventoryManager.update_row(
						"Quests", "ID", 105, {"Unlocked": 1}
					)

	if lis1_quests_open:
		_update_ui_quests()


# Срабатывает автоматически, когда встроенный Timer досчитает до 0
func _on_quest3_timeout() -> void:
	var quest = BaseInventoryManager.find_row("Quests", "ID", 103)
	var need_val := int(quest.get("Need", 10))

	BaseInventoryManager.update_row(
		"Quests", "ID", 103, {"Have": need_val}
	)

	_check_and_update_quests_logic()

	if lis1_quests_open:
		_update_ui_quests()

# Функция учета посещения баз для квестов 102 и 104 (без повторов)
func _handle_base_for_quests_102_104(base_id: int) -> void:
	var target_bases := [1001, 1002, 1003, 1005]

	if base_id not in target_bases:
		return

	for q_id in [102, 104]:
		var quest = BaseInventoryManager.find_row("Quests", "ID", q_id)

		if quest.is_empty() or int(quest.get("Unlocked", 0)) != 1:
			continue

		if base_id not in quest_visited_bases[q_id]:
			quest_visited_bases[q_id].append(base_id)

			var new_have: int = quest_visited_bases[q_id].size()
			var need: int = int(quest.get("Need", 4))

			if new_have >= need:
				BaseInventoryManager.update_row(
					"Quests", "ID", q_id,
					{"Have": new_have, "Unlocked": 2}
				)

				if q_id == 102:
					BaseInventoryManager.update_row(
						"Quests", "ID", 103, {"Unlocked": 1}
					)
				elif q_id == 104:
					BaseInventoryManager.update_row(
						"Quests", "ID", 105, {"Unlocked": 1}
					)
			else:
				BaseInventoryManager.update_row(
					"Quests", "ID", q_id, {"Have": new_have}
				)

# --- ОБНОВЛЕНИЕ UI КВЕСТОВ ИЗ БАЗЫ ДАННЫХ ---

func _update_ui_quests() -> void:
	for q_btn in quest_nodes:
		if not q_btn:
			continue

		var q_id := int(q_btn.text.strip_edges())
		if q_id == 0:
			continue

		var row = BaseInventoryManager.find_row("Quests", "ID", q_id)
		if row.is_empty():
			continue

		var unlocked := int(row.get("Unlocked", 0))
		var have := int(row.get("Have", 0))
		var need := int(row.get("Need", 1))

		var name_lbl := q_btn.get_node_or_null("Name") as Label
		var desc_lbl := q_btn.get_node_or_null("Description") as Label
		var prog_lbl := q_btn.get_node_or_null("Progress") as Label

		if unlocked == 0:
			if name_lbl:
				name_lbl.text = "Квест поки недоступний"
			if desc_lbl:
				desc_lbl.text = "???"
			if prog_lbl:
				prog_lbl.text = "Недоступно"

		elif unlocked == 2:
			if name_lbl:
				name_lbl.text = str(row.get("Name", ""))
			if desc_lbl:
				desc_lbl.text = str(row.get("Description", ""))
			if prog_lbl:
				prog_lbl.text = "Виконано"

		elif unlocked == 1:
			if name_lbl:
				name_lbl.text = str(row.get("Name", ""))
			if desc_lbl:
				desc_lbl.text = str(row.get("Description", ""))

			if prog_lbl:
				if q_id == 103:
					if quest3_timer_node and not quest3_timer_node.is_stopped():
						var rem_time := int(ceil(quest3_timer_node.time_left))
						prog_lbl.text = "(Таймер: %d сек.)" % rem_time
					else:
						prog_lbl.text = "(Выполнено)"
				else:
					prog_lbl.text = "(%d) / (%d)" % [have, need]


# --- ОСТАЛЬНЫЕ МЕТОДЫ КАРТЫ И БАЗ ---
func _update_markers_scale() -> void:
	for m in marker_nodes:
		if m:
			if m.size != Vector2.ZERO:
				m.pivot_offset = m.size / 2.0
			elif m.custom_minimum_size != Vector2.ZERO:
				m.pivot_offset = m.custom_minimum_size / 2.0
				
			var m_id = m.text.to_int()
			if m_id == current_base_id:
				m.scale = Vector2(1.2, 1.2)
				m.move_to_front()
			else:
				m.scale = Vector2(1.0, 1.0)


func _update_roads_appearance() -> void:
	if lis1_roads == null:
		return

	var active_row: Dictionary = {}

	for row in BaseInventoryManager.get_rows("Bases"):
		if int(row.get("ISActive", 0)) == 1:
			active_row = row
			break

	var allowed_roads: Array[String] = []

	if not active_row.is_empty():
		for i in range(1, 6):
			var road_value = active_row.get("Base" + str(i), 0)

			if road_value != null and int(road_value) != 0:
				allowed_roads.append(str(int(road_value)))

	for road_node in lis1_roads.get_children():
		road_node.visible = true

		if road_node.name in allowed_roads:
			road_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			lis1_roads.move_child(
				road_node,
				lis1_roads.get_child_count() - 1
			)
		else:
			road_node.modulate = Color(0.35, 0.35, 0.35, 0.7)


func _on_quests_open_close_pressed() -> void:
	if is_animating: return
	is_animating = true

	quests_is_open = !quests_is_open
	var target_pos = quests_visible_pos if quests_is_open else quests_hidden_pos

	var tween = create_tween().set_parallel(true)
	tween.tween_property(quests_panel, "position", target_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if quests_open_close_btn:
		quests_open_close_btn.pivot_offset = quests_open_close_btn.size / 2.0
		quests_open_close_btn.rotation_degrees += 180.0

	await tween.finished
	is_animating = false

func _on_lis1_quest_category_pressed() -> void:
	if is_animating: return
	is_animating = true

	lis1_quests_open = !lis1_quests_open

	if lis1_arrow:
		lis1_arrow.pivot_offset = lis1_arrow.size / 2.0
		var arrow_tween = create_tween()
		arrow_tween.tween_property(lis1_arrow, "rotation_degrees", lis1_arrow.rotation_degrees + 180.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await arrow_tween.finished

	if lis1_quests_open:
		_check_and_update_quests_logic()
		_update_ui_quests()
		if lis1_quests_vbox: lis1_quests_vbox.visible = true
	else:
		if lis1_quests_vbox: lis1_quests_vbox.visible = false

	is_animating = false

func _on_active_lis1_pressed() -> void:
	if is_animating or map_node == null: return
	is_animating = true

	if active_lis1: active_lis1.visible = false
	if close_button: close_button.visible = true

	var tween = create_tween().set_parallel(true)
	tween.tween_property(map_node, "position", zoomed_map_pos, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(map_node, "scale", zoomed_map_scale, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if lis1_node:
		tween.tween_property(lis1_node, "scale", zoomed_lis1_scale, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished

	_load_current_active_base()
	_update_markers_scale()
	_update_roads_appearance()

	if lis1_markers:
		lis1_markers.visible = true
		create_tween().tween_property(lis1_markers, "modulate:a", 1.0, 0.25)
		
	if lis1_roads:
		lis1_roads.visible = true
		var fade_roads = create_tween()
		fade_roads.tween_property(lis1_roads, "modulate:a", 1.0, 0.25)
		await fade_roads.finished

	is_animating = false

func _on_close_map_pressed() -> void:
	if is_animating or map_node == null: return
	is_animating = true

	if BasePanel.position == base_visible_pos:
		await slide_to(BasePanel, hidden_pos)
		name_label.text = ""

	if lis1_markers:
		lis1_markers.visible = false
		lis1_markers.modulate.a = 0.0
		
	if lis1_roads:
		lis1_roads.visible = false
		lis1_roads.modulate.a = 0.0

	if close_button: close_button.visible = false
	if active_lis1: active_lis1.visible = true

	var tween = create_tween().set_parallel(true)
	tween.tween_property(map_node, "position", default_map_pos, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(map_node, "scale", default_map_scale, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if lis1_node:
		tween.tween_property(lis1_node, "scale", default_lis1_scale, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished

	is_animating = false


func _on_marker_pressed(marker_button: Button) -> void:
	if is_animating:
		return

	current_base_id = marker_button.text.to_int()
	_update_markers_scale()

	var row = BaseInventoryManager.find_row(
		"Bases", "ID", current_base_id
	)

	if not row.is_empty():
		if base_num_label:
			base_num_label.text = "База № %s" % str(row.get("BaseNum", ""))

		if base_name_label:
			base_name_label.text = "—%s—" % str(row.get("BaseName", ""))

		if monsters_label:
			monsters_label.text = str(row.get("Monsters", ""))

		var desc = row.get("Description", row.get("description", ""))

		if description_label:
			description_label.text = str(desc)

		var is_active_base := int(row.get("ISActive", 0)) == 1

		if is_active_base:
			if play_button:
				play_button.visible = false
			if hardness_label:
				hardness_label.text = "Ви тут"
		else:
			if play_button:
				play_button.visible = true

			var road := _get_road_to(row)

			if hardness_label:
				hardness_label.text = str(road.get("Hardness", ""))

	is_animating = true

	if BasePanel.position == base_visible_pos:
		await slide_to(BasePanel, hidden_pos)

	if name_label:
		name_label.text = "Ліс"

	var anim_tween := create_tween()
	anim_tween.tween_property(
		BasePanel, "position", base_visible_pos, 0.4
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await anim_tween.finished
	is_animating = false


func _on_road_pressed(road_button: Button) -> void:
	var road_number := road_button.name.to_int()

	var road = BaseInventoryManager.find_row(
		"Roads", "Number", road_number
	)

	if not road.is_empty() and hardness_label:
		hardness_label.text = str(road.get("Hardness", ""))


func _on_base_play_pressed() -> void:
	if current_base_id == -1:
		return

	var selected_base = BaseInventoryManager.find_row(
		"Bases", "ID", current_base_id
	)

	if selected_base.is_empty():
		return

	var road := _get_road_to(selected_base)
	var difficulty := GameFlow.get_difficulty(
		StringName(str(road.get("Difficulty", GameFlow.DEFAULT_DIFFICULTY)))
	)

	for row in BaseInventoryManager.get_rows("Bases"):
		row["ISActive"] = 1 if int(row.get("ID", -1)) == current_base_id else 0

	BaseInventoryManager.save_data()

	print("База с ID %d теперь активна" % current_base_id)

	_handle_base_for_quests_102_104(current_base_id)

	_update_markers_scale()
	_update_roads_appearance()
	_check_and_update_quests_logic()

	if play_button:
		play_button.visible = false

	if hardness_label:
		hardness_label.text = "Ви тут"

	GameFlow.start_run(difficulty)


func _get_road_to(target_base: Dictionary) -> Dictionary:
	for row in BaseInventoryManager.get_rows("Bases"):
		if int(row.get("ISActive", 0)) != 1:
			continue

		var road_num = row.get("Base" + str(int(target_base.get("BaseNum", 0))), 0)

		if road_num == null or int(road_num) == 0:
			return {}

		return BaseInventoryManager.find_row("Roads", "Number", int(road_num))

	return {}


func slide_to(node: Control, target_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(node, "position", target_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
