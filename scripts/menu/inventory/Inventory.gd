
extends Control

@onready var inventory_grid: GridContainer = $InventoryGrid
@onready var obj_info_panel: Panel = $ObjInfo

@onready var info_icon: Button = $ObjInfo/Info/Icon
@onready var info_name_label: Label = $ObjInfo/Info/Name
@onready var info_rarity_label: Label = $ObjInfo/Info/Rarity
@onready var info_description_label: Label = $ObjInfo/Info/Description
@onready var info_quantity_label: Label = $ObjInfo/Info/Quantity
@onready var btn_use: Button = $ObjInfo/Info/Use

@onready var sell_minus_btn: Button = $ObjInfo/Info/Selling/Minus
@onready var sell_input_quantity: LineEdit = $ObjInfo/Info/Selling/Quantity
@onready var sell_plus_btn: Button = $ObjInfo/Info/Selling/Plus
@onready var btn_sell: Button = $ObjInfo/Info/Sell

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

	if obj_info_panel:
		obj_info_panel.position = hidden_position
		obj_info_panel.visible = false

	if btn_use:
		btn_use.disabled = true

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
		return

	for cat in CATEGORIES:
		for rar in RARITIES:
			var item_node = get_node_or_null("%s/%s" % [cat, rar])

			# Предмет мог быть перемещён в InventoryGrid.
			if not item_node:
				item_node = inventory_grid.get_node_or_null(rar)

			if not item_node:
				continue

			var id_node = item_node.get_node_or_null("ID")

			if not id_node is Label:
				continue

			var obj_id = id_node.text.strip_edges()

			if obj_id.is_empty():
				continue

			var db_item: Dictionary = BaseInventoryManager.find_object_by_id(obj_id)

			if db_item.is_empty():
				item_node.visible = false
				continue

			var quantity := int(db_item.get("Quantity", 0))

			if quantity > 0:
				if item_node.get_parent() != inventory_grid:
					if item_node.get_parent():
						item_node.get_parent().remove_child(item_node)

					inventory_grid.add_child(item_node)

				item_node.visible = true

				var target_button = item_node if item_node is BaseButton else item_node.get_node_or_null("Button")

				if not target_button and not item_node is BaseButton:
					target_button = item_node.find_child("*Button*", true, false)

				if target_button is BaseButton:
					var callback := _on_inventory_item_clicked.bind(obj_id, item_node)

					if not target_button.pressed.is_connected(callback):
						target_button.pressed.connect(callback)

				elif not item_node.has_meta("click_connected"):
					item_node.set_meta("click_connected", true)

					var gui_detector := Button.new()
					gui_detector.flat = true
					gui_detector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
					gui_detector.pressed.connect(
						_on_inventory_item_clicked.bind(obj_id, item_node)
					)

					item_node.add_child(gui_detector)
			else:
				item_node.visible = false


# --------------------------------------------------
# ВЫБОР ПРЕДМЕТА
# --------------------------------------------------

func _on_inventory_item_clicked(
	obj_id: String,
	item_node: Control
) -> void:
	current_selected_id = obj_id

	var db_item: Dictionary = BaseInventoryManager.find_object_by_id(
		current_selected_id
	)

	if db_item.is_empty():
		return

	current_item_unit_price = int(db_item.get("Emount", 0))
	max_item_count = int(db_item.get("Quantity", 0))

	if max_item_count <= 0:
		return

	if info_name_label:
		info_name_label.text = str(db_item.get("Name", ""))

	if info_rarity_label:
		info_rarity_label.text = str(db_item.get("Rarity", "Common"))

	if info_description_label:
		info_description_label.text = str(db_item.get("Descriprion", ""))

	if info_quantity_label:
		info_quantity_label.text = tr("У вас є: %d") % max_item_count

	if info_icon and item_node:
		if item_node is BaseButton:
			info_icon.icon = item_node.icon
		else:
			var inner_btn = item_node.get_node_or_null("Button")

			if inner_btn is BaseButton:
				info_icon.icon = inner_btn.icon

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
			0.35
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


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
