extends Control

@export_category("UI")
@export var category_label: Label

@export_category("Category Buttons")
@export var weapons_button: Button
@export var consumables_button: Button
@export var repair_button: Button

@export_category("Items")
@export var item_view_scene: PackedScene
@export var items_container: GridContainer


# Клерки находятся внутри Background/Clerks.
@onready var clerks: Array = [
	get_node_or_null("Background/Clerks/Clerk1"),
	get_node_or_null("Background/Clerks/Clerk2"),
	get_node_or_null("Background/Clerks/Clerk3")
]


enum ShopCategory {
	WEAPONS,
	CONSUMABLES,
	REPAIR
}


var current_category: ShopCategory = ShopCategory.WEAPONS


const CATEGORY_NAMES := {
	ShopCategory.WEAPONS: "Оружие",
	ShopCategory.CONSUMABLES: "Расходники",
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

	_ensure_shop_data()
	render_shop()


# --------------------------------------------------
# Инициализация ассортимента
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
			"rarity": str(item.get("Rarity", "Common")),
			"unique_key": "%s_%s" % [
				category_key.to_lower(),
				str(item.get("ID", ""))
			]
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
	var clerk_index: int = int(
		CATEGORY_CLERKS[current_category]
	)

	for i in range(clerks.size()):
		var clerk = clerks[i]

		if clerk is CanvasItem:
			clerk.visible = i == clerk_index
			clerk.modulate.a = 1.0 if i == clerk_index else 0.0


# --------------------------------------------------
# Карточки товаров
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
		shop_item.count_label.visible = false

	if shop_item.price_label:
		shop_item.price_label.visible = true
		shop_item.price_label.text = str(data.get("price", 0))

	items_container.add_child(shop_item)
	shop_item.visible = true

	var unique_key := str(data.get("unique_key", ""))

	if BaseInventoryManager.is_purchased(unique_key):
		_apply_sold_out_state(shop_item)
	elif shop_item.button:
		shop_item.button.pressed.connect(
			_buy_item.bind(data, shop_item)
		)


# --------------------------------------------------
# Покупка
# --------------------------------------------------

func _buy_item(data: Dictionary, shop_item: item_view) -> void:
	var item_id := str(data.get("id", ""))
	var unique_key := str(data.get("unique_key", ""))
	var price := int(data.get("price", 0))

	var inventory_item := BaseInventoryManager.find_object_by_id(
		item_id
	)

	if inventory_item.is_empty():
		push_warning(
			"Предмет с ID %s не найден в objects.json" % item_id
		)
		return

	if BaseInventoryManager.is_purchased(unique_key):
		return

	if not BaseInventoryManager.spend_money(price):
		print("Недостаточно средств!")
		return

	inventory_item["Quantity"] = \
		int(inventory_item.get("Quantity", 0)) + 1

	BaseInventoryManager.save_data()
	BaseInventoryManager.mark_as_purchased(unique_key)
	BaseInventoryManager.inventory_changed.emit()

	_apply_sold_out_state(shop_item)


func _apply_sold_out_state(shop_item: item_view) -> void:
	if shop_item.button:
		shop_item.button.disabled = true
		shop_item.button.modulate = Color(
			0.6, 0.6, 0.6, 1.0
		)

	shop_item.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --------------------------------------------------
# Сигналы менеджера
# --------------------------------------------------

func _on_game_manager_shop_refreshed() -> void:
	render_shop()
