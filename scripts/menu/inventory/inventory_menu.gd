
extends Control

@export_category("Grid")
@export var inventory_grid: GridContainer
@export var obj_info_panel: Panel

@export_category("Info")
@export var info_icon: Button
@export var info_name_label: Label
@export var info_rarity_label: Label
@export var info_description_label: Label
@export var info_quantity_label: Label

@export_category("Sell")
@export var sell_minus_btn: Button
@export var sell_input_quantity: LineEdit
@export var sell_plus_btn: Button
@export var btn_sell: Button

@export_category("Inventory")
@export var item_view_scene: PackedScene

var current_selected_id: String = ""
var current_item_unit_price: int = 0
var max_item_count: int = 1

var hidden_position: Vector2 = Vector2(1920.0, 139.0)
var shown_position: Vector2 = Vector2(1454.0, 139.0)

const CATEGORIES = ["Boost", "Bullet", "Car"]
const RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]


func _ready() -> void:
	Settings.language_changed.connect(_refresh_language)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if not BaseInventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		BaseInventoryManager.inventory_changed.connect(_on_inventory_changed)

	if obj_info_panel:
		obj_info_panel.position = hidden_position
		obj_info_panel.visible = false

	#if btn_use:
		#btn_use.disabled = true

	if btn_sell and not btn_sell.pressed.is_connected(_on_sell_button_pressed):
		btn_sell.pressed.connect(_on_sell_button_pressed)

	if sell_input_quantity and not sell_input_quantity.text_changed.is_connected(_on_sell_quantity_changed):
		sell_input_quantity.text_changed.connect(_on_sell_quantity_changed)

	if sell_minus_btn and not sell_minus_btn.pressed.is_connected(_on_minus_pressed):
		sell_minus_btn.pressed.connect(_on_minus_pressed)

	if sell_plus_btn and not sell_plus_btn.pressed.is_connected(_on_plus_pressed):
		sell_plus_btn.pressed.connect(_on_plus_pressed)

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

		var item_instance = item_view_scene.instantiate() as item_view

		if not item_instance:
			push_warning("Inventory: item_view_scene не содержит item_view.")
			continue

		inventory_grid.add_child(item_instance)
		item_instance.setup(item_data)
		item_instance.price_label.hide()

		if not item_instance.button:
			push_warning("Inventory: в item_view не назначена кнопка.")
			continue

		item_instance.button.pressed.connect(
			_on_inventory_item_clicked.bind(item_instance)
		)


# --------------------------------------------------
# ВЫБОР ПРЕДМЕТА
# --------------------------------------------------

func _on_inventory_changed() -> void:
	refresh_inventory()


func _on_inventory_item_clicked(item_node: item_view) -> void:
	if item_node.item_id.is_empty():
		return

	current_selected_id = item_node.item_id

	var db_item := BaseInventoryManager.find_object_by_id(
		current_selected_id
	)

	if db_item.is_empty():
		return

	current_item_unit_price = int(db_item.get("Emount", 0))
	max_item_count = int(db_item.get("Quantity", 0))

	info_name_label.text = str(db_item.get("Name", ""))
	info_rarity_label.text = str(db_item.get("Rarity", ""))
	info_description_label.text = str(db_item.get("Descriprion", ""))

	info_quantity_label.text = tr("У вас є: %d") % max_item_count

	if item_node.button:
		info_icon.icon = item_node.button.icon

	if sell_input_quantity:
		sell_input_quantity.text = "1"

	update_sell_button_text()

	if obj_info_panel:
		obj_info_panel.visible = true

		var tween := create_tween()
		tween.tween_property(
			obj_info_panel,
			"position",
			shown_position,
			0.25
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --------------------------------------------------
# КОЛИЧЕСТВО ДЛЯ ПРОДАЖИ
# --------------------------------------------------

func _on_sell_quantity_changed(new_text: String) -> void:
	if max_item_count <= 0:
		return

	var val := new_text.to_int()

	if val > max_item_count:
		sell_input_quantity.text = str(max_item_count)
		sell_input_quantity.caret_column = sell_input_quantity.text.length()

	update_sell_button_text()


func _on_minus_pressed() -> void:
	var current_val := sell_input_quantity.text.to_int()

	if current_val > 1:
		sell_input_quantity.text = str(current_val - 1)
		update_sell_button_text()


func _on_plus_pressed() -> void:
	var current_val := sell_input_quantity.text.to_int()

	if current_val < max_item_count:
		sell_input_quantity.text = str(current_val + 1)
		update_sell_button_text()


func update_sell_button_text() -> void:
	if not btn_sell:
		return

	if max_item_count <= 0:
		btn_sell.text = "Продати"
		return

	var count_to_sell := clampi(
		sell_input_quantity.text.to_int(),
		1,
		max_item_count
	)

	var total_price := int(round(
		count_to_sell * current_item_unit_price * 0.67
	))

	btn_sell.text = tr("Продати %d за: %d") % [count_to_sell, total_price]


# --------------------------------------------------
# ПРОДАЖА ПРЕДМЕТА
# --------------------------------------------------

func _on_sell_button_pressed() -> void:
	if current_selected_id.is_empty():
		return

	var db_item: Dictionary = BaseInventoryManager.find_object_by_id(
		current_selected_id
	)

	if db_item.is_empty():
		return

	var current_quantity := int(db_item.get("Quantity", 0))

	if current_quantity <= 0:
		return

	var count_to_sell := clampi(
		sell_input_quantity.text.to_int(),
		1,
		current_quantity
	)

	var total_price := int(round(
		count_to_sell * int(db_item.get("Emount", 0)) * 0.67
	))

	# Обновляем количество предметов в общем JSON.
	db_item["Quantity"] = current_quantity - count_to_sell

	# Сохраняем изменения предметов.
	BaseInventoryManager.save_data()

	# Начисляем деньги через общий менеджер.
	BaseInventoryManager.add_money(total_price)

	print("Продано успешно на сумму: ", total_price)

	if obj_info_panel:
		obj_info_panel.visible = false

	current_selected_id = ""

	refresh_inventory()


func _refresh_language() -> void:
	if obj_info_panel.visible:
		info_quantity_label.text = tr("У вас є: %d") % max_item_count
		update_sell_button_text()
