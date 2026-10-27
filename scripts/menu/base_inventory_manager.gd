
extends Node

signal money_changed(new_amount: int)
signal shop_refreshed

const SOURCE_PATH := "res://objects.json"
const SAVE_PATH := "user://objects.json"

var data: Dictionary = {}

var purchased_items: Dictionary = {}

var shop_time_left: float = 10.0
var shop_timer_active: bool = true

var current_shop_data: Dictionary = {}
var active_clerk_index: int = 0


func _ready() -> void:
	load_data()


# --------------------------------------------------
# ЗАГРУЗКА И СОХРАНЕНИЕ JSON
# --------------------------------------------------

func load_data() -> void:
	var file: FileAccess

	if FileAccess.file_exists(SAVE_PATH):
		file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	else:
		file = FileAccess.open(SOURCE_PATH, FileAccess.READ)

	if file == null:
		push_error("Не удалось открыть objects.json")
		return

	var json_text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_text)

	if not parsed is Dictionary:
		push_error("Ошибка формата objects.json")
		return

	data = parsed

	# Создаём сохранение при первом запуске.
	if not FileAccess.file_exists(SAVE_PATH):
		save_data()
	elif _add_missing_tables():
		save_data()


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	purchased_items.clear()
	current_shop_data.clear()
	load_data()
	money_changed.emit(get_player_money())


func _add_missing_tables() -> bool:
	var source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_PATH))

	if not source is Dictionary:
		return false

	var added := false

	for table_name in source:
		if not data.has(table_name):
			data[table_name] = source[table_name]
			added = true
		elif _add_missing_rows(data[table_name], source[table_name]):
			added = true

	return added


func _add_missing_rows(rows: Variant, source_rows: Variant) -> bool:
	if not rows is Array or not source_rows is Array:
		return false

	var by_id := {}

	for row in rows:
		if row is Dictionary and row.has("ID"):
			by_id[_key(row["ID"])] = row

	var added := false

	for source_row in source_rows:
		if not source_row is Dictionary or not source_row.has("ID"):
			continue

		var row = by_id.get(_key(source_row["ID"]))

		if row == null:
			rows.append(source_row)
			added = true
			continue

		for field in source_row:
			if not row.has(field):
				row[field] = source_row[field]
				added = true

	return added


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Не удалось сохранить objects.json")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()


# --------------------------------------------------
# ПОИСК ЗАПИСЕЙ
# --------------------------------------------------

func find_object_by_name(object_name: String) -> Dictionary:
	for item in data.get("Objects", []):
		if str(item.get("Name", "")) == object_name:
			return item

	return {}


func find_object_by_id(object_id: String) -> Dictionary:
	for item in data.get("Objects", []):
		if _key(item.get("ID", "")) == _key(object_id):
			return item

	return {}


func get_car_upgrades(type_name: String) -> Array:
	var result: Array = []

	for item in data.get("Car", []):
		if str(item.get("Type", "")) == type_name:
			result.append(item)

	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("Level", 0)) < int(b.get("Level", 0))
	)

	return result


# --------------------------------------------------
# ДЕНЬГИ
# --------------------------------------------------

func get_player_money() -> int:
	var money_data: Array = data.get("Money", [])

	if money_data.is_empty():
		return 0

	return int(money_data[0].get("MONEY", 0))


func set_player_money(amount: int) -> void:
	if not data.has("Money") or data["Money"].is_empty():
		data["Money"] = [{"MONEY": amount}]
	else:
		data["Money"][0]["MONEY"] = amount

	save_data()
	money_changed.emit(amount)


func spend_money(amount: int) -> bool:
	if amount < 0:
		return false

	var current_money := get_player_money()

	if current_money < amount:
		return false

	set_player_money(current_money - amount)
	return true


func add_money(amount: int) -> void:
	if amount < 0:
		return

	set_player_money(get_player_money() + amount)


# --------------------------------------------------
# ПОКУПКИ УЛУЧШЕНИЙ
# --------------------------------------------------

func purchase_car_upgrade(car_item: Dictionary) -> bool:
	var car_id = car_item.get("ID", null)

	if car_id == null:
		return false

	# Находим актуальную запись, а не полагаемся на копию словаря.
	var upgrade: Dictionary = {}

	for item in data.get("Car", []):
		if str(item.get("ID", "")) == str(car_id):
			upgrade = item
			break

	if upgrade.is_empty():
		return false

	if int(upgrade.get("Purchased", 0)) == 1:
		return false

	# Нельзя покупать улучшение, если предыдущий уровень не куплен.
	var upgrades := get_car_upgrades(str(upgrade.get("Type", "")))

	for item in upgrades:
		if str(item.get("ID", "")) == str(car_id):
			break

		if int(item.get("Purchased", 0)) != 1:
			return false

	var object_item := find_object_by_name(
		str(upgrade.get("TypeObj", ""))
	)

	if object_item.is_empty():
		return false

	var required_objects := int(upgrade.get("NumObj", 0))
	var money_cost := int(upgrade.get("Money", 0))

	if required_objects < 0 or money_cost < 0:
		return false

	if int(object_item.get("Quantity", 0)) < required_objects:
		return false

	if get_player_money() < money_cost:
		return false

	# Сначала проверяем всё, затем изменяем данные.
	object_item["Quantity"] = (
		int(object_item.get("Quantity", 0)) - required_objects
	)

	upgrade["Purchased"] = 1

	# Списываем деньги и сохраняем все изменения одним сохранением.
	data["Money"][0]["MONEY"] = get_player_money() - money_cost

	save_data()
	money_changed.emit(get_player_money())

	return true


# --------------------------------------------------
# ОСТАЛЬНАЯ ЛОГИКА МАГАЗИНА
# --------------------------------------------------

func _process(delta: float) -> void:
	if shop_timer_active:
		shop_time_left -= delta

		if shop_time_left <= 0.0:
			trigger_shop_refresh()


func trigger_shop_refresh() -> void:
	shop_time_left = 10.0
	active_clerk_index = (active_clerk_index + 1) % 3
	current_shop_data.clear()
	shop_refreshed.emit()


func mark_as_purchased(unique_id: String) -> void:
	purchased_items[unique_id] = true


func is_purchased(unique_id: String) -> bool:
	return purchased_items.has(unique_id)


func generate_category_data_from_templates(
	templates: Dictionary,
	count: int
) -> Array:
	var category_pool: Array = []

	for rarity_key in templates.keys():
		var template_node = templates[rarity_key]

		if not template_node:
			continue

		var id_node = template_node.get_node_or_null("ID")

		if not id_node is Label:
			continue

		var item_id = id_node.text.strip_edges()

		if item_id.is_empty():
			continue

		var row := find_object_by_id(item_id)

		if not row.is_empty():
			category_pool.append({
				"id": item_id,
				"rarity": rarity_key,
				"percent": float(row.get("Percent", 0.0))
			})

	if category_pool.is_empty():
		return []

	var generated_items: Array = []

	for i in range(count):
		var selected := _roll_item_by_percent(category_pool)

		if selected.is_empty():
			continue

		var row := find_object_by_id(str(selected["id"]))

		if row.is_empty():
			continue

		generated_items.append({
			"id": str(row.get("ID", "")),
			"name": row.get("Name", ""),
			"desc": row.get("Descriprion", ""),
			"price": int(row.get("Emount", 0)),
			"rarity": selected["rarity"],
			"icon": str(row.get("IconPath", "")),
			"unique_key": "item_%s_%s_%s" % [
				str(row.get("ID", "")), str(i), str(randi())
			]
		})

	return generated_items


func generate_sweet_data_from_templates(
	all_templates_array: Array
) -> Dictionary:
	var all_allowed_ids: Array[String] = []

	for templates_dict in all_templates_array:
		for rarity_key in templates_dict.keys():
			var template_node = templates_dict[rarity_key]

			if not template_node:
				continue

			var id_node = template_node.get_node_or_null("ID")

			if not id_node is Label:
				continue

			var item_id = id_node.text.strip_edges()

			if not item_id.is_empty() and item_id not in all_allowed_ids:
				all_allowed_ids.append(item_id)

	if all_allowed_ids.is_empty():
		return {}

	var random_id: String = all_allowed_ids[
		randi() % all_allowed_ids.size()
	]

	var row := find_object_by_id(random_id)

	if row.is_empty():
		return {}

	var original_price := int(row.get("Emount", 0))

	return {
		"id": str(row.get("ID", "")),
		"name": row.get("Name", ""),
		"desc": row.get("Descriprion", ""),
		"price": int(round(original_price * 0.75)),
		"rarity": str(row.get("Rarity", "Common")),
		"icon": str(row.get("IconPath", "")),
		"unique_key": "sweet_%s_%s" % [
			str(row.get("ID", "")), str(randi())
		]
	}


func _roll_item_by_percent(pool: Array) -> Dictionary:
	var total_weight := 0.0

	for item in pool:
		total_weight += maxf(float(item.get("percent", 0.0)), 0.0)

	if total_weight <= 0.0:
		return pool[0] if not pool.is_empty() else {}

	var roll := randf() * total_weight
	var current_sum := 0.0

	for item in pool:
		current_sum += maxf(float(item.get("percent", 0.0)), 0.0)

		if roll < current_sum:
			return item

	return pool.back()


# --------------------------------------------------
# УНИВЕРСАЛЬНАЯ РАБОТА С JSON-ТАБЛИЦАМИ
# --------------------------------------------------

func get_rows(table_name: String) -> Array:
	var rows = data.get(table_name, [])

	if rows is Array:
		return rows

	return []


func _key(value: Variant) -> String:
	if value is float and value == floorf(value):
		return str(int(value))

	return str(value)


func find_row(
	table_name: String,
	field: String,
	value: Variant
) -> Dictionary:
	for row in get_rows(table_name):
		if _key(row.get(field, "")) == _key(value):
			return row

	return {}


func update_row(
	table_name: String,
	field: String,
	value: Variant,
	changes: Dictionary
) -> bool:
	var row := find_row(table_name, field, value)

	if row.is_empty():
		return false

	for key in changes:
		row[key] = changes[key]

	save_data()
	return true


func update_rows(
	table_name: String,
	changes: Dictionary
) -> void:
	for row in get_rows(table_name):
		for key in changes:
			row[key] = changes[key]

	save_data()
