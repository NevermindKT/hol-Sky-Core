extends Control

@export_category("Grid")
@export var inventory_grid: GridContainer

@export_category("Object Info")
@export var object_info: ObjInfo

@export_category("Inventory")
@export var item_view_scene: PackedScene

const SELL_PRICE_MULTIPLIER := 0.67

var current_selected_id: String = ""


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if not Settings.language_changed.is_connected(_refresh_language):
		Settings.language_changed.connect(_refresh_language)

	if not BaseInventoryManager.inventory_changed.is_connected(
		_on_inventory_changed
	):
		BaseInventoryManager.inventory_changed.connect(
			_on_inventory_changed
		)

	if object_info:
		object_info.hide()

		if not object_info.sell_requested.is_connected(_on_sell_requested):
			object_info.sell_requested.connect(_on_sell_requested)

	refresh_inventory()


# --------------------------------------------------
# ОБНОВЛЕНИЕ ИНВЕНТАРЯ
# --------------------------------------------------

func refresh_inventory() -> void:
	if not inventory_grid:
		push_warning("Inventory: inventory_grid не назначен.")
		return

	if not item_view_scene:
		push_warning("Inventory: item_view_scene не назначена.")
		return

	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()

	var objects: Array = BaseInventoryManager.get_rows("Objects")

	for item_data in objects:
		if not item_data is Dictionary:
			continue

		var quantity := int(item_data.get("Quantity", 0))
		if quantity <= 0:
			continue

		var item_instance := item_view_scene.instantiate() as item_view

		if not item_instance:
			push_warning(
				"Inventory: item_view_scene не содержит item_view."
			)
			continue

		item_instance.setup(item_data)
		inventory_grid.add_child(item_instance)

		if item_instance.price_label:
			item_instance.price_label.hide()

		if item_instance.button:
			item_instance.button.pressed.connect(
				_on_inventory_item_clicked.bind(item_instance.item_id)
			)


# --------------------------------------------------
# ВЫБОР ПРЕДМЕТА
# --------------------------------------------------

func _on_inventory_item_clicked(item_id: String) -> void:
	if item_id.is_empty() or not object_info:
		return

	var db_item: Dictionary = BaseInventoryManager.find_object_by_id(item_id)

	if db_item.is_empty():
		return

	current_selected_id = item_id

	var info_data := {
		"id": str(db_item.get("ID", "")),
		"name": str(db_item.get("Name", "")),
		"desc": str(db_item.get("Descriprion", "")),
		"rarity": str(db_item.get("Rarity", "")),
		"icon": str(db_item.get("IconPath", "")),
		"price": int(db_item.get("Emount", 0)),
		"Quantity": int(db_item.get("Quantity", 0))
	}

	object_info.setup(info_data, ObjInfo.Mode.INVENTORY)


# --------------------------------------------------
# ПРОДАЖА
# --------------------------------------------------

func _on_sell_requested(data: Dictionary, amount: int) -> void:
	var item_id := str(data.get("id", data.get("ID", "")))

	if item_id.is_empty():
		return

	var db_item: Dictionary = BaseInventoryManager.find_object_by_id(item_id)

	if db_item.is_empty():
		return

	var current_quantity := int(db_item.get("Quantity", 0))

	if current_quantity <= 0:
		return

	var count_to_sell := clampi(amount, 1, current_quantity)
	var unit_price := int(db_item.get("Emount", 0))

	var total_price := int(round(
		count_to_sell * unit_price * SELL_PRICE_MULTIPLIER
	))

	db_item["Quantity"] = current_quantity - count_to_sell

	BaseInventoryManager.save_data()
	BaseInventoryManager.add_money(total_price)

	print(
		"Продано: ", count_to_sell,
		" шт. Получено: ", total_price
	)

	current_selected_id = ""

	if object_info:
		object_info.hide()

	refresh_inventory()


# --------------------------------------------------
# СИГНАЛЫ МЕНЕДЖЕРА
# --------------------------------------------------

func _on_inventory_changed() -> void:
	refresh_inventory()


func _refresh_language() -> void:
	if object_info and object_info.visible:
		var db_item: Dictionary = BaseInventoryManager.find_object_by_id(
			current_selected_id
		)

		if not db_item.is_empty():
			_on_inventory_item_clicked(current_selected_id)
