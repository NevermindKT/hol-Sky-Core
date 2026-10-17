extends Node

var purchased_items: Dictionary = {}

var shop_time_left: float = 10.0
var shop_timer_active: bool = true

var current_shop_data: Dictionary = {}
var active_clerk_index: int = 0

# --- ПЕРЕМЕННЫЕ ТАЙМЕРА КВЕСТА 103 ---
var quest103_time_left: float = 0.0
var quest103_active: bool = false

var db: SQLite = null

signal money_changed(new_amount: int)
signal shop_refreshed 
signal quest103_tick(time_left: float) # Сигнал для обновления интерфейса
signal quest103_finished             # Сигнал окончания таймера

func _ready() -> void:
	_init_database()

func _init_database() -> void:
	db = SQLite.new()
	db.path = "objects.db"
	db.open_db()

# --- СИСТЕМА ДЕНЕГ ИЗ БАЗЫ ДАННЫХ ---

func get_player_money() -> int:
	if not db:
		_init_database()
	
	db.query("SELECT MONEY FROM Money LIMIT 1;")
	var res = db.query_result
	if not res.is_empty():
		return int(res[0].get("MONEY", 0))
	return 0

func set_player_money(amount: int) -> void:
	if not db:
		_init_database()
		
	db.query("UPDATE Money SET MONEY = %d;" % amount)
	emit_signal("money_changed", amount)

func spend_money(amount: int) -> bool:
	var current_money = get_player_money()
	if current_money >= amount:
		var new_money = current_money - amount
		set_player_money(new_money)
		return true
	return false

func add_money(amount: int) -> void:
	var current_money = get_player_money()
	var new_money = current_money + amount
	set_player_money(new_money)

# --- ЛОГИКА ТАЙМЕРА КВЕСТА 103 ---

func start_quest103_timer(duration: float) -> void:
	if not quest103_active and quest103_time_left <= 0.0:
		quest103_time_left = duration
		quest103_active = true

func _process(delta: float) -> void:
	# Магазин
	if shop_timer_active:
		shop_time_left -= delta
		if shop_time_left <= 0:
			trigger_shop_refresh()

	# Таймер квеста 103 работает глобально
	if quest103_active:
		quest103_time_left -= delta
		emit_signal("quest103_tick", quest103_time_left)
		
		if quest103_time_left <= 0:
			quest103_time_left = 0.0
			quest103_active = false
			emit_signal("quest103_finished")

func trigger_shop_refresh() -> void:
	shop_time_left = 10.0 
	active_clerk_index = (active_clerk_index + 1) % 3 
	current_shop_data.clear()
	emit_signal("shop_refreshed")

func mark_as_purchased(unique_id: String) -> void:
	purchased_items[unique_id] = true

func is_purchased(unique_id: String) -> bool:
	return purchased_items.has(unique_id)

func generate_category_data_from_templates(templates: Dictionary, count: int) -> Array:
	if not db:
		_init_database()

	var category_pool = []
	for rarity_key in templates.keys():
		var template_node = templates[rarity_key]
		if not template_node: continue
		
		var id_node = template_node.get_node_or_null("ID")
		if not id_node: continue
		
		var item_id = ""
		if id_node is Label:
			item_id = id_node.text.strip_edges()
		elif "text" in id_node:
			item_id = str(id_node.text).strip_edges()
		else:
			continue
			
		if item_id == "": continue

		db.query("SELECT Percent FROM Objects WHERE ID = '%s';" % [item_id])
		if not db.query_result.is_empty():
			var percent = float(db.query_result[0]["Percent"])
			category_pool.append({"id": item_id, "rarity": rarity_key, "percent": percent})

	if category_pool.is_empty(): return []

	var generated_items = []
	for i in range(count):
		var selected = _roll_item_by_percent(category_pool)
		if selected:
			db.query("SELECT * FROM Objects WHERE ID = '%s';" % [selected["id"]])
			if not db.query_result.is_empty():
				var row = db.query_result[0]
				generated_items.append({
					"id": str(row["ID"]),
					"name": row["Name"],
					"desc": row["Descriprion"],
					"price": int(row["Emount"]),
					"rarity": selected["rarity"],
					"icon": str(row.get("IconPath", "")),
					"unique_key": "item_" + str(row["ID"]) + "_" + str(i) + "_" + str(randi())
				})
	return generated_items

func generate_sweet_data_from_templates(all_templates_array: Array) -> Dictionary:
	if not db:
		_init_database()

	var all_allowed_ids = []
	for templates_dict in all_templates_array:
		for rarity_key in templates_dict.keys():
			var template_node = templates_dict[rarity_key]
			if not template_node: continue
			var id_node = template_node.get_node_or_null("ID")
			if id_node:
				var item_id = ""
				if id_node is Label:
					item_id = id_node.text.strip_edges()
				elif "text" in id_node:
					item_id = str(id_node.text).strip_edges()
					
				if item_id != "" and not item_id in all_allowed_ids:
					all_allowed_ids.append(item_id)

	if all_allowed_ids.is_empty(): return {}

	var random_id = all_allowed_ids[randi() % all_allowed_ids.size()]
	db.query("SELECT * FROM Objects WHERE ID = '%s';" % [random_id])
	if db.query_result.is_empty(): return {}

	var row = db.query_result[0]
	var original_price = int(row["Emount"])
	
	return {
		"id": str(row["ID"]),
		"name": row["Name"],
		"desc": row["Descriprion"],
		"price": int(round(original_price * 0.75)),
		"rarity": str(row.get("Rarity", "Common")),
		"icon": str(row.get("IconPath", "")),
		"unique_key": "sweet_" + str(row["ID"]) + "_" + str(randi())
	}

func _roll_item_by_percent(pool: Array) -> Dictionary:
	var total_weight = 0.0
	for item in pool: total_weight += item["percent"]
	if total_weight <= 0.0: return pool[0]
	var roll = randf() * total_weight
	var current_sum = 0.0
	for item in pool:
		current_sum += item["percent"]
		if roll <= current_sum: return item
	return pool[0]
