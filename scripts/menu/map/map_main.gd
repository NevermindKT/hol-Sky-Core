extends Control

# --- СУЩЕСТВУЮЩИЕ ПЕРЕМЕННЫЕ КАРТЫ И БАЗ ---
@onready var map_node: Panel = $Map 
@onready var lis1_node: Control = $Map/Lis1 
@onready var lis1_roads: Control = $Map/Lis1/Roads 
@onready var lis1_markers: Control = $Map/Lis1/Markers 
@onready var active_lis1: Button = $Map/Lis1/ActiveLis1

@onready var BasePanel: Panel = $Base
@onready var base_num_label: Label = $Base/BaseNum
@onready var base_name_label: Label = $Base/BaseName
@onready var hardness_label: Label = $Base/Hardness
@onready var monsters_label: Label = $Base/Monsters
@onready var description_label: Label = $Base/Description
@onready var play_button: Button = $Base/Play

@onready var close_button: Button = $Close
@onready var name_label: Label = $Header/Block/Name

# --- ПЕРЕМЕННЫЕ СИСТЕМЫ КВЕСТОВ ---
@onready var quests_panel: Panel = $Quests
@onready var quests_open_close_btn: Button = $Quests/OpenClose
@onready var lis1_quest_category: Button = $Quests/Locations/Lis1
@onready var lis1_arrow: Control = $Quests/Locations/Lis1/Arrow
@onready var lis1_quests_vbox: VBoxContainer = $Quests/Locations/Quests

# Ссылки на 5 фиксированных квестов
@onready var quest_nodes: Array[Button] = [
	$Quests/Locations/Quests/Quest1,
	$Quests/Locations/Quests/Quest2,
	$Quests/Locations/Quests/Quest3,
	$Quests/Locations/Quests/Quest4,
	$Quests/Locations/Quests/Quest5
]

# Ссылка на ваш узел Timer в квесте 3
@onready var quest3_timer_node: Timer = $Quests/Locations/Quests/Quest3/Progress/Timer

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
var db: SQLite = null

func _ready() -> void:
	_init_database()

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

	var markers = [$Map/Lis1/Markers/Lis11, $Map/Lis1/Markers/Lis12, $Map/Lis1/Markers/Lis13, $Map/Lis1/Markers/Lis14, $Map/Lis1/Markers/Lis15]
	for m in markers:
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

func _init_database() -> void:
	db = SQLite.new()
	db.path = "res://objects.db"
	db.open_db()

func _load_current_active_base() -> void:
	if db == null: return
	db.query("SELECT ID FROM Bases WHERE ISActive = 1;")
	var res = db.query_result
	if not res.is_empty():
		current_base_id = int(res[0].get("ID", -1))
	
	_update_markers_scale()
	_update_roads_appearance()
	_check_and_update_quests_logic()

# --- ЛОГИКА ПРОВЕРКИ И ВЫПОЛНЕНИЯ КВЕСТОВ ---
func _check_and_update_quests_logic() -> void:
	if db == null: return

	for q_btn in quest_nodes:
		if not q_btn: continue
		var q_id = int(q_btn.text.strip_edges()) # ID квеста берется из текста кнопки
		if q_id == 0: continue

		db.query("SELECT Unlocked, Have, Need FROM Quests WHERE ID = %d;" % q_id)
		var q_res = db.query_result
		if q_res.is_empty(): continue
		
		var unlocked = int(q_res[0].get("Unlocked", 0))
		var have = int(q_res[0].get("Have", 0))
		var need = int(q_res[0].get("Need", 1))

		# Если квест доступен для выполнения (Unlocked == 1)
		if unlocked == 1:
			var calculated_have = have

			# Квесты 101 и 105: Have = 1 если база 1004 активна (ISActive == 1)
			if q_id == 101 or q_id == 105:
				db.query("SELECT ISActive FROM Bases WHERE ID = 1004;")
				var b_res = db.query_result
				if not b_res.is_empty() and int(b_res[0].get("ISActive", 0)) == 1:
					calculated_have = 1
				else:
					calculated_have = 0
				
				db.query("UPDATE Quests SET Have = %d WHERE ID = %d;" % [calculated_have, q_id])

			# Квест 103: подстраиваем таймер под Need из базы и запускаем, если он еще не запущен
			elif q_id == 103:
				if have < need:
					if quest3_timer_node and quest3_timer_node.is_stopped() and quest3_timer_node.time_left == 0.0:
						quest3_timer_node.wait_time = float(need) # Устанавливаем время из базы данных (Need)
						quest3_timer_node.start()
				else:
					calculated_have = need
					db.query("UPDATE Quests SET Have = %d WHERE ID = %d;" % [calculated_have, q_id])

			# Проверка завершения квеста
			if calculated_have >= need:
				db.query("UPDATE Quests SET Unlocked = 2 WHERE ID = %d;" % q_id)
				
				if q_id == 101:
					db.query("UPDATE Quests SET Unlocked = 1 WHERE ID = 102;")
				elif q_id == 102:
					db.query("UPDATE Quests SET Unlocked = 1 WHERE ID = 103;")
				elif q_id == 103:
					db.query("UPDATE Quests SET Unlocked = 1 WHERE ID = 104;")
				elif q_id == 104:
					db.query("UPDATE Quests SET Unlocked = 1 WHERE ID = 105;")

	if lis1_quests_open:
		_update_ui_quests()

# Срабатывает автоматически, когда встроенный Timer досчитает до 0
func _on_quest3_timeout() -> void:
	if db == null: return
	db.query("SELECT Need FROM Quests WHERE ID = 103;")
	var res = db.query_result
	var need_val = int(res[0].get("Need", 10)) if not res.is_empty() else 10
	
	db.query("UPDATE Quests SET Have = %d WHERE ID = 103;" % need_val)
	_check_and_update_quests_logic()
	if lis1_quests_open:
		_update_ui_quests()

# Функция учета посещения баз для квестов 102 и 104 (без повторов)
func _handle_base_for_quests_102_104(base_id: int) -> void:
	var target_bases = [1001, 1002, 1003, 1005]
	if base_id not in target_bases:
		return

	for q_id in [102, 104]:
		db.query("SELECT Unlocked, Have, Need FROM Quests WHERE ID = %d;" % q_id)
		var res = db.query_result
		if not res.is_empty() and int(res[0].get("Unlocked", 0)) == 1:
			if base_id not in quest_visited_bases[q_id]:
				quest_visited_bases[q_id].append(base_id)
				var new_have = quest_visited_bases[q_id].size()
				var need = int(res[0].get("Need", 4))

				db.query("UPDATE Quests SET Have = %d WHERE ID = %d;" % [new_have, q_id])

				if new_have >= need:
					db.query("UPDATE Quests SET Unlocked = 2 WHERE ID = %d;" % q_id)
					if q_id == 102:
						db.query("UPDATE Quests SET Unlocked = 1 WHERE ID = 103;")
					elif q_id == 104:
						db.query("UPDATE Quests SET Unlocked = 1 WHERE ID = 105;")

# --- ОБНОВЛЕНИЕ UI КВЕСТОВ ИЗ БАЗЫ ДАННЫХ ---
func _update_ui_quests() -> void:
	if db == null: return

	for q_btn in quest_nodes:
		if not q_btn: continue
		var q_id = int(q_btn.text.strip_edges()) # ID берется из текста кнопки
		if q_id == 0: continue

		db.query("SELECT * FROM Quests WHERE ID = %d;" % q_id)
		var result = db.query_result
		if result.is_empty(): continue

		var row = result[0]
		var unlocked = int(row.get("Unlocked", 0))
		var have = int(row.get("Have", 0))
		var need = int(row.get("Need", 1))

		var name_lbl = q_btn.get_node_or_null("Name") as Label
		var desc_lbl = q_btn.get_node_or_null("Description") as Label
		var prog_lbl = q_btn.get_node_or_null("Progress") as Label

		if unlocked == 0:
			if name_lbl: name_lbl.text = "Квест поки недоступний"
			if desc_lbl: desc_lbl.text = "???"
			if prog_lbl: prog_lbl.text = "Недоступно"
		elif unlocked == 2:
			if name_lbl: name_lbl.text = str(row.get("Name", ""))
			if desc_lbl: desc_lbl.text = str(row.get("Description", ""))
			if prog_lbl: prog_lbl.text = "Виконано"
		elif unlocked == 1:
			if name_lbl: name_lbl.text = str(row.get("Name", ""))
			if desc_lbl: desc_lbl.text = str(row.get("Description", ""))
			if prog_lbl:
				if q_id == 103:
					if quest3_timer_node and not quest3_timer_node.is_stopped():
						var rem_time = int(ceil(quest3_timer_node.time_left))
						prog_lbl.text = "(Таймер: %d сек.)" % rem_time
					else:
						prog_lbl.text = "(Виконано)"
				else:
					prog_lbl.text = "(%d) / (%d)" % [have, need]

# --- ОСТАЛЬНЫЕ МЕТОДЫ КАРТЫ И БАЗ ---
func _update_markers_scale() -> void:
	var markers = [$Map/Lis1/Markers/Lis11, $Map/Lis1/Markers/Lis12, $Map/Lis1/Markers/Lis13, $Map/Lis1/Markers/Lis14, $Map/Lis1/Markers/Lis15]
	for m in markers:
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
	if db == null or lis1_roads == null: return

	db.query("SELECT * FROM Bases WHERE ISActive = 1;")
	var result = db.query_result
	
	var allowed_roads = []
	if not result.is_empty():
		var active_row = result[0]
		for i in range(1, 6):
			var col_name = "Base" + str(i)
			if active_row.has(col_name) and active_row[col_name] != null:
				var road_val = int(active_row[col_name])
				if road_val != 0:
					allowed_roads.append(str(road_val))

	for road_node in lis1_roads.get_children():
		road_node.visible = true
		var road_num = road_node.name

		if road_num in allowed_roads:
			road_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			lis1_roads.move_child(road_node, lis1_roads.get_child_count() - 1)
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
	if is_animating: return

	current_base_id = marker_button.text.to_int()
	_update_markers_scale()

	if db:
		db.query("SELECT * FROM Bases WHERE ID = %d;" % current_base_id)
		var result = db.query_result
		if not result.is_empty():
			var row = result[0]
			if base_num_label: base_num_label.text = "База № %s" % str(row.get("BaseNum", ""))
			if base_name_label: base_name_label.text = "—%s—" % str(row.get("BaseName", ""))
			if monsters_label: monsters_label.text = str(row.get("Monsters", ""))
			
			var desc = row.get("Description", "")
			if desc == "" and row.has("description"):
				desc = row.get("description", "")
			if description_label: 
				description_label.text = str(desc)

			var is_active_base = int(row.get("ISActive", 0)) == 1

			if is_active_base:
				if play_button: play_button.visible = false
				if hardness_label: hardness_label.text = "Ви тут"
			else:
				if play_button: play_button.visible = true
				
				var found_hardness = false
				for i in range(1, 6):
					var r_num = row.get("Base" + str(i))
					if r_num != null and int(r_num) != 0:
						db.query("SELECT Hardness FROM Roads WHERE Number = %d;" % int(r_num))
						var r_res = db.query_result
						if not r_res.is_empty():
							if hardness_label:
								hardness_label.text = str(r_res[0].get("Hardness", ""))
							found_hardness = true
						break
				if not found_hardness and hardness_label:
					hardness_label.text = ""

	is_animating = true

	if BasePanel.position == base_visible_pos:
		await slide_to(BasePanel, hidden_pos)

	if name_label: name_label.text = "Ліс"

	var anim_tween = create_tween()
	anim_tween.tween_property(BasePanel, "position", base_visible_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	await anim_tween.finished
	is_animating = false

func _on_road_pressed(road_button: Button) -> void:
	var road_number = road_button.name.to_int()
	if db:
		db.query("SELECT Hardness FROM Roads WHERE Number = %d;" % road_number)
		var result = db.query_result
		if not result.is_empty():
			var road_hardness = result[0].get("Hardness", "")
			if hardness_label:
				hardness_label.text = str(road_hardness)

func _on_base_play_pressed() -> void:
	if current_base_id == -1 or db == null:
		return

	db.query("UPDATE Bases SET ISActive = 0;")
	db.query("UPDATE Bases SET ISActive = 1 WHERE ID = %d;" % current_base_id)
	
	print("База с ID %d теперь активна (ISActive = 1)" % current_base_id)

	# Проверяем прогресс квестов 102 и 104 при активации базы
	_handle_base_for_quests_102_104(current_base_id)

	_update_markers_scale()
	_update_roads_appearance()
	_check_and_update_quests_logic()

	if play_button: play_button.visible = false
	if hardness_label: hardness_label.text = "Ви тут"

func slide_to(node: Control, target_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(node, "position", target_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
