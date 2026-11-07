
extends Control

@export_category("UI")
@export var category_label: Label
@export var object_info: ObjInfo

@export_category("Category Buttons")
@export var weapons_button: Button
@export var consumables_button: Button
@export var repair_button: Button

@export_category("Items")
@export var item_view_scene: PackedScene
@export var items_container: GridContainer

@export_category("Clerks")
@export var clerks: Array[Control] = []
@export var clerk_slide_distance: float = 180.0
@export var clerk_animation_duration: float = 0.35

var language_option: OptionButton

var _clerk_tween: Tween
var _active_clerk_index: int = -1
var _clerk_home_positions: Array[Vector2] = []

enum ShopCategory {
	WEAPONS,
	CONSUMABLES,
	REPAIR
}

var current_category: ShopCategory = ShopCategory.WEAPONS

const CATEGORY_NAMES := {

	ShopCategory.WEAPONS: "Зброя",
	ShopCategory.CONSUMABLES: "Витратні матеріали",
	ShopCategory.REPAIR: "Ремонт"
}

const CATEGORY_KEYS := {
	ShopCategory.WEAPONS: "Weapons",
	ShopCategory.CONSUMABLES: "Consumables",
	ShopCategory.REPAIR: "Repair"
}

const CATEGORY_CLERKS := {
	ShopCategory.WEAPONS: 0,
	ShopCategory.CONSUMABLES: 1,
	ShopCategory.REPAIR: 2
}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if object_info:
		object_info.close_panel()

		if not object_info.purchase_requested.is_connected(_buy_item):
			object_info.purchase_requested.connect(_buy_item)

	if not Settings.language_changed.is_connected(render_shop):
		Settings.language_changed.connect(render_shop)

	if not BaseInventoryManager.shop_refreshed.is_connected(
		_on_game_manager_shop_refreshed
	):
		BaseInventoryManager.shop_refreshed.connect(
			_on_game_manager_shop_refreshed
		)

	if weapons_button:
		weapons_button.pressed.connect(
			select_category.bind(ShopCategory.WEAPONS)
		)

	if consumables_button:
		consumables_button.pressed.connect(
			select_category.bind(ShopCategory.CONSUMABLES)
		)

	if repair_button:
		repair_button.pressed.connect(
			select_category.bind(ShopCategory.REPAIR)
		)


	_initialize_clerks()
	_ensure_shop_data()
	render_shop()


# --------------------------------------------------
# Ассортимент
# --------------------------------------------------

func _ensure_shop_data() -> void:
	for category in [
		ShopCategory.WEAPONS,
		ShopCategory.CONSUMABLES,
		ShopCategory.REPAIR
	]:
		var key := _get_category_key(category)

		if not BaseInventoryManager.current_shop_data.has(key):
			BaseInventoryManager.current_shop_data[key] = \
				_generate_category_data(key)


func _generate_category_data(category_key: String) -> Array:
	var result: Array = []

	for item in BaseInventoryManager.get_rows("Objects"):
		if not item is Dictionary:
			continue

		var item_category := str(item.get("ShopCategory", ""))

		if item_category.to_lower() != category_key.to_lower():
			continue

		result.append({
			"id": str(item.get("ID", "")),
			"name": str(item.get("Name", "")),
			"desc": str(item.get("Descriprion", "")),
			"price": int(item.get("Emount", 0)),
			"icon": str(item.get("IconPath", "")),
			"rarity": str(item.get("Rarity", "Common"))
		})

	return result


func _get_category_key(category: ShopCategory) -> String:
	return str(CATEGORY_KEYS[category]).to_lower()


# --------------------------------------------------
# Отображение магазина
# --------------------------------------------------

func render_shop() -> void:
	_ensure_shop_data()
	select_category(current_category)


func select_category(category: ShopCategory) -> void:
	current_category = category

	if category_label:
		category_label.text = tr(CATEGORY_NAMES[category])

	BaseInventoryManager.active_clerk_index = \
		int(CATEGORY_CLERKS[category])

	_clear_container(items_container)

	var category_key := _get_category_key(category)
	var items: Array = BaseInventoryManager.current_shop_data.get(
		category_key,
		[]
	)

	_render_category_items(items)
	_update_clerks()


func _clear_container(container: Control) -> void:
	if not container:
		return

	for child in container.get_children():
		child.queue_free()


func _render_category_items(items_data: Array) -> void:
	if not items_container:
		return

	for item_data in items_data:
		if item_data is Dictionary:
			_create_card_from_data(item_data)


# --------------------------------------------------
# Клерки
# --------------------------------------------------

func _update_clerks() -> void:
	var new_index: int = int(CATEGORY_CLERKS[current_category])

	if new_index < 0 or new_index >= clerks.size():
		return

	if not is_instance_valid(clerks[new_index]):
		return

	if _active_clerk_index == -1:
		_active_clerk_index = new_index
		clerks[new_index].position = _clerk_home_positions[new_index]
		clerks[new_index].show()
		return

	if _active_clerk_index == new_index:
		return

	if _clerk_tween and _clerk_tween.is_running():
		_clerk_tween.kill()

	for i in range(clerks.size()):
		var clerk := clerks[i]

		if not is_instance_valid(clerk):
			continue

		clerk.position = _clerk_home_positions[i]
		clerk.visible = i == _active_clerk_index
		clerk.modulate.a = 1.0

	var old_index := _active_clerk_index

	var old_clerk := clerks[old_index]
	var new_clerk := clerks[new_index]

	if not is_instance_valid(old_clerk):
		_active_clerk_index = new_index
		new_clerk.position = _clerk_home_positions[new_index]
		new_clerk.show()
		return

	var direction := 1.0 if new_index > old_index else -1.0

	var old_position := _clerk_home_positions[old_index]
	var new_position := _clerk_home_positions[new_index]

	new_clerk.position = new_position + Vector2(
		direction * clerk_slide_distance,
		0.0
	)
	new_clerk.modulate.a = 0.0
	new_clerk.show()

	_clerk_tween = create_tween()
	_clerk_tween.set_parallel(true)
	_clerk_tween.set_trans(Tween.TRANS_CUBIC)
	_clerk_tween.set_ease(Tween.EASE_IN_OUT)

	_clerk_tween.tween_property(
		old_clerk,
		"position",
		old_position - Vector2(direction * clerk_slide_distance, 0.0),
		clerk_animation_duration
	)

	_clerk_tween.tween_property(
		new_clerk,
		"position",
		new_position,
		clerk_animation_duration
	)
	
	_clerk_tween.tween_property(
		old_clerk,
		"modulate:a",
		0.0,
		clerk_animation_duration
	)

	_clerk_tween.tween_property(
		new_clerk,
		"modulate:a",
		1.0,
		clerk_animation_duration
	)

	_clerk_tween.chain().tween_callback(
		func():
			old_clerk.hide()
			old_clerk.position = old_position
			old_clerk.modulate.a = 1.0
	)

	_active_clerk_index = new_index


func _initialize_clerks() -> void:
	for clerk in clerks:
		if not is_instance_valid(clerk):
			_clerk_home_positions.append(Vector2.ZERO)
			continue

		_clerk_home_positions.append(clerk.position)
		clerk.hide()

# --------------------------------------------------
# Карточки
# --------------------------------------------------

func _create_card_from_data(data: Dictionary) -> void:
	if not item_view_scene:
		push_warning("Shop: item_view_scene не назначена.")
		return

	var shop_item := item_view_scene.instantiate() as item_view

	if not shop_item:
		push_warning("Shop: сцена не содержит скрипт item_view.")
		return

	var item_data := {
		"id": str(data.get("id", "")),
		"icon": str(data.get("icon", "")),
		"price": int(data.get("price", 0)),
		"Quantity": 0
	}

	shop_item.setup(item_data)

	if shop_item.count_label:
		shop_item.count_label.hide()

	if shop_item.price_label:
		shop_item.price_label.show()
		shop_item.price_label.text = str(data.get("price", 0))

	items_container.add_child(shop_item)

	if shop_item.button:
		shop_item.button.pressed.connect(
			_on_item_selected.bind(data)
		)


func _on_item_selected(data: Dictionary) -> void:
	if not object_info:
		push_warning("Shop: не назначена сцена ObjInfo.")
		return

	var info_data := {
		"id": str(data.get("id", "")),
		"name": str(data.get("name", "")),
		"desc": str(data.get("desc", "")),
		"price": int(data.get("price", 0)),
		"icon": str(data.get("icon", "")),
		"rarity": str(data.get("rarity", "Common")),
		"Quantity": 0
	}

	object_info.setup(info_data, ObjInfo.Mode.SHOP)


# --------------------------------------------------
# Покупка
# --------------------------------------------------

func _buy_item(data: Dictionary, amount: int) -> void:
	var item_id := str(data.get("id", ""))
	var price := int(data.get("price", 0))

	if amount <= 0:
		return

	if price < 0:
		push_warning("Shop: у предмета указана отрицательная цена.")
		return

	var inventory_item: Dictionary = \
		BaseInventoryManager.find_object_by_id(item_id)

	if inventory_item.is_empty():
		push_warning(
			"Предмет с ID %s не найден в objects.json" % item_id
		)
		return

	var total_price: int = price * amount

	if not BaseInventoryManager.spend_money(total_price):
		print("Недостаточно средств! Нужно: ", total_price)
		return

	inventory_item["Quantity"] = \
		int(inventory_item.get("Quantity", 0)) + amount

	BaseInventoryManager.save_data()
	BaseInventoryManager.inventory_changed.emit()

	print(
		"Куплено: ", amount,
		" шт. Общая стоимость: ", total_price
	)


# --------------------------------------------------
# Сигналы менеджера
# --------------------------------------------------

func _on_game_manager_shop_refreshed() -> void:
	render_shop()
