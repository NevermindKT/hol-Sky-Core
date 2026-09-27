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

var db: SQLite = null
var current_selected_id: String = ""
var current_item_unit_price: int = 0
var max_item_count: int = 1

var hidden_position: Vector2 = Vector2(1920.0, 139.0)
var shown_position: Vector2 = Vector2(1454.0, 139.0)

const CATEGORIES = ["Boost", "Bullet", "Car"]
const RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

func _ready() -> void:
	_init_database()
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

func _init_database() -> void:
	db = SQLite.new()
	db.path = "res://objects.db"
	db.open_db()

func refresh_inventory() -> void:
	if not db:
		_init_database()
		
	if not inventory_grid: return

	for cat in CATEGORIES:
		for rar in RARITIES:
			var item_node = get_node_or_null("%s/%s" % [cat, rar])
			if not item_node:
				continue
			
			var id_node = item_node.get_node_or_null("ID")
			if not id_node or not id_node is Label:
				continue
			
			var obj_id = id_node.text.strip_edges()
			if obj_id == "":
				continue
			
			db.query("SELECT * FROM Objects WHERE ID = '%s';" % [obj_id])
			var results = db.query_result
			
			if not results.is_empty():
				var db_item = results[0]
				var q = int(db_item["Quantity"])
				
				if q > 0:
					if item_node.get_parent() != inventory_grid:
						if item_node.get_parent():
							item_node.get_parent().remove_child(item_node)
						inventory_grid.add_child(item_node)
					
					item_node.visible = true
					
					var target_button = item_node if item_node is BaseButton else item_node.get_node_or_null("Button")
					if not target_button and not item_node is BaseButton:
						target_button = item_node.find_child("*Button*", true, false)
					
					if target_button and target_button is BaseButton:
						if not target_button.pressed.is_connected(_on_inventory_item_clicked.bind(db_item, item_node)):
							target_button.pressed.connect(_on_inventory_item_clicked.bind(db_item, item_node))
					elif not item_node.has_meta("click_connected"):
						item_node.set_meta("click_connected", true)
						var gui_detector = Button.new()
						gui_detector.flat = true
						gui_detector.set_anchors_and_presets(Control.PRESET_FULL_RECT)
						gui_detector.pressed.connect(_on_inventory_item_clicked.bind(db_item, item_node))
						item_node.add_child(gui_detector)
				else:
					item_node.visible = false
					if item_node.get_parent() == inventory_grid:
						item_node.get_parent().remove_child(item_node)

func _on_inventory_item_clicked(item: Dictionary, item_node: Control) -> void:
	current_selected_id = str(item["ID"])
	
	db.query("SELECT * FROM Objects WHERE ID = '%s';" % [current_selected_id])
	if db.query_result.is_empty(): return
	var db_item = db.query_result[0]
	
	current_item_unit_price = int(db_item["Emount"])
	max_item_count = int(db_item["Quantity"])
	
	if info_name_label:
		info_name_label.text = str(db_item["Name"])
	if info_rarity_label:
		info_rarity_label.text = str(db_item["Rarity"])
	if info_description_label:
		info_description_label.text = str(db_item["Descriprion"])
	if info_quantity_label:
		info_quantity_label.text = "У вас є: " + str(db_item["Quantity"])
		
	if info_icon and item_node:
		if item_node is BaseButton:
			info_icon.icon = item_node.icon
		else:
			var inner_btn = item_node.get_node_or_null("Button")
			if inner_btn and inner_btn is BaseButton:
				info_icon.icon = inner_btn.icon

	if sell_input_quantity:
		sell_input_quantity.text = "1"
		
	update_sell_button_text()

	if obj_info_panel:
		obj_info_panel.visible = true
		var tween = create_tween()
		tween.tween_property(obj_info_panel, "position", shown_position, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_sell_quantity_changed(new_text: String) -> void:
	var val = new_text.to_int()
	if val > max_item_count:
		sell_input_quantity.text = str(max_item_count)
		sell_input_quantity.caret_column = sell_input_quantity.text.length()
	update_sell_button_text()

func _on_minus_pressed() -> void:
	var current_val = sell_input_quantity.text.to_int()
	if current_val > 1:
		sell_input_quantity.text = str(current_val - 1)
		update_sell_button_text()

func _on_plus_pressed() -> void:
	var current_val = sell_input_quantity.text.to_int()
	if current_val < max_item_count:
		sell_input_quantity.text = str(current_val + 1)
		update_sell_button_text()

func update_sell_button_text() -> void:
	if not btn_sell: return
	var count_to_sell = clampi(sell_input_quantity.text.to_int(), 1, max_item_count)
	var total_price = int(round(count_to_sell * current_item_unit_price * 0.67))
	btn_sell.text = "Продати " + str(count_to_sell) + " за: " + str(total_price)

func _on_sell_button_pressed() -> void:
	var count_to_sell = clampi(sell_input_quantity.text.to_int(), 1, max_item_count)
	var total_price = int(round(count_to_sell * current_item_unit_price * 0.67))
	
	# Списываем проданные предметы из базы данных
	db.query("UPDATE Objects SET Quantity = Quantity - %d WHERE ID = '%s';" % [count_to_sell, current_selected_id])
	
	# Начисляем деньги через обновленный менеджер (запишется в таблицу Money и обновит хедер)
	GameManager.add_money(total_price)
		
	print("Продано успешно на сумму: ", total_price)
	if obj_info_panel:
		obj_info_panel.visible = false
	refresh_inventory()
