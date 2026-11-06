extends Control

@export_category("Grid")
@export var inventory_grid: GridContainer

@export_category("Object Info")
@export var object_info: ObjInfo

@export_category("Inventory")
@export var item_view_scene: PackedScene

@export_category("Loadout")
@export var loadout_slots: Array[LoadoutSlot] = []
@export var loadout_hint: Label
@export var loadout_total: Label

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
		object_info.close_panel()

		if not object_info.sell_requested.is_connected(_on_sell_requested):
			object_info.sell_requested.connect(_on_sell_requested)

	for loadout_slot in loadout_slots:
		loadout_slot.slot_clicked.connect(_on_loadout_slot_clicked)

	BoostManager.slots_changed.connect(_refresh_loadout_total)
	BoostManager.sanitize_loadout()

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
			item_instance.button.set_drag_forwarding(
				_get_item_drag_data.bind(item_instance), Callable(), Callable()
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
# БАГАЖНИК (АКТИВКИ НА 1/2/3)
# --------------------------------------------------

func _get_item_drag_data(_at_position: Vector2, item_instance: item_view) -> Variant:
	if not BoostManager.is_slot_boost(BoostManager.boost_for_object(item_instance.item_id)):
		return null

	var preview := TextureRect.new()
	preview.texture = item_instance.button.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(80, 80)
	preview.position = -preview.size * 0.5
	preview.modulate.a = 0.85
	var holder := Control.new()
	holder.add_child(preview)
	item_instance.button.set_drag_preview(holder)

	return {"object_id": item_instance.item_id}


func _on_loadout_slot_clicked(slot: int) -> void:
	if current_selected_id.is_empty():
		return

	if not BoostManager.add_to_slot(slot, current_selected_id):
		loadout_slots[slot].flash_denied()


func _refresh_loadout_total() -> void:
	if loadout_total:
		loadout_total.text = "%d / %d" % [BoostManager.total_loaded(), BoostManager.MAX_PER_RUN]


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
		object_info.close_panel()

	refresh_inventory()
	BoostManager.sanitize_loadout()


# --------------------------------------------------
# СИГНАЛЫ МЕНЕДЖЕРА
# --------------------------------------------------

func _on_inventory_changed() -> void:
	refresh_inventory()
	BoostManager.sanitize_loadout()


func _refresh_language() -> void:
	if object_info and object_info.visible:
		var db_item: Dictionary = BaseInventoryManager.find_object_by_id(
			current_selected_id
		)

		if not db_item.is_empty():
			_on_inventory_item_clicked(current_selected_id)
