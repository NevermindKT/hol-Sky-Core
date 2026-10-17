extends Control

@onready var level_grid: VBoxContainer = $LevelGrid
@onready var level_obj: Button = $LevelObj

# Элементы управления для выбора типов
@onready var type_object_label: Label = $Types/Selling/Object
@onready var btn_previous: Button = $Types/Selling/Previous
@onready var btn_next: Button = $Types/Selling/Next
@onready var type_image_button: Button = $Types/Image # Теперь строго Button
@onready var types_image_container: HBoxContainer = $TypesImage # HBoxContainer

var db: SQLite = null

const RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const CATEGORIES = ["Car", "Boost", "Bullet"]
const TYPES = ["Шини", "Двері", "Двигун", "Підвіска", "Передня рама"]
var current_type_index: int = 0

var template_min_height: float = 0.0

func _ready() -> void:
	_init_database()
	if level_obj:
		template_min_height = level_obj.custom_minimum_size.y
		if template_min_height <= 0.0:
			template_min_height = level_obj.size.y
		level_obj.visible = false
		
	if btn_previous and not btn_previous.pressed.is_connected(_on_previous_pressed):
		btn_previous.pressed.connect(_on_previous_pressed)
		
	if btn_next and not btn_next.pressed.is_connected(_on_next_pressed):
		btn_next.pressed.connect(_on_next_pressed)
		
	update_type_display()

func _init_database() -> void:
	db = SQLite.new()
	db.path = "res://objects.db"
	db.open_db()

func _on_previous_pressed() -> void:
	current_type_index = (current_type_index - 1 + TYPES.size()) % TYPES.size()
	update_type_display()

func _on_next_pressed() -> void:
	current_type_index = (current_type_index + 1) % TYPES.size()
	update_type_display()

func update_type_display() -> void:
	var current_type_name = TYPES[current_type_index]
	if type_object_label:
		type_object_label.text = current_type_name
		
	update_types_image_display(current_type_name)
	refresh_car_upgrades()

func update_types_image_display(active_type: String) -> void:
	if not types_image_container:
		return
		
	var found_icon: Texture2D = null
	
	for child in types_image_container.get_children():
		if not (child is Control):
			continue
			
		var node_text = ""
		var text_node = child.get_node_or_null("Label") if child.has_node("Label") else child
		if text_node is Label:
			node_text = text_node.text.strip_edges()
		elif child.name:
			node_text = child.name.strip_edges()
			
		var matches = false
		if active_type == "Шини" and (node_text == "Tire" or node_text == "Шини"): matches = true
		elif active_type == "Двері" and (node_text == "Door" or node_text == "Двері"): matches = true
		elif active_type == "Двигун" and (node_text == "Engine" or node_text == "Двигун"): matches = true
		elif active_type == "Підвіска" and (node_text == "Suspension" or node_text == "Підвіска"): matches = true
		elif active_type == "Передня рама" and (node_text == "Bullbar" or node_text == "Передня рама"): matches = true
		
		if matches:
			child.visible = true
			child.modulate.a = 1.0
			
			# Так как child — это кнопка (например, Tire), берем ее .icon
			if child is BaseButton:
				found_icon = child.icon
			else:
				var inner_btn = child.get_node_or_null("Button") if child.has_node("Button") else null
				if inner_btn is BaseButton:
					found_icon = inner_btn.icon
		else:
			child.visible = false
			child.modulate.a = 0.0
			
	# Устанавливаем иконку в кнопку Types/Image
	if type_image_button and found_icon:
		type_image_button.icon = found_icon

func refresh_car_upgrades() -> void:
	if not db:
		_init_database()
		
	if not level_grid: return
	
	for child in level_grid.get_children():
		child.queue_free()
		
	var target_type = TYPES[current_type_index]

	db.query("SELECT * FROM Car WHERE Type = '%s' ORDER BY Level ASC;" % [target_type])
	var car_items = db.query_result
	
	if car_items.is_empty():
		return

	var previous_purchased = true

	for car_item in car_items:
		if not level_obj: break
		
		var item_node = level_obj.duplicate() as Button
		item_node.visible = true
		
		item_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if template_min_height > 0:
			item_node.custom_minimum_size.y = template_min_height
		
		var lbl_level = item_node.get_node_or_null("Level/Level")
		if lbl_level is Label:
			lbl_level.text = str(car_item["Level"])
			
		var lbl_name = item_node.get_node_or_null("Level/Name")
		var btn_sell = item_node.get_node_or_null("Level/Sell")
		var det_node = item_node.get_node_or_null("Level/Det")
		var mon_node = item_node.get_node_or_null("Level/Mon")
		
		var type_obj = str(car_item["TypeObj"])
		db.query("SELECT * FROM Objects WHERE Name = '%s';" % [type_obj])
		var obj_result = db.query_result
		
		var current_quantity = 0
		var obj_id = ""
		if not obj_result.is_empty():
			current_quantity = int(obj_result[0]["Quantity"])
			obj_id = str(obj_result[0]["ID"])
			
		var is_purchased = int(car_item.get("Purchased", 0)) == 1
		var num_obj = int(car_item["NumObj"])
		var money_cost = int(car_item["Money"])
		
		if det_node:
			var found_icon = _find_scene_icon_by_id(obj_id) if obj_id != "" else null
			
			if det_node is Button:
				det_node.text = "%d / %d" % [current_quantity, num_obj]
				if found_icon:
					det_node.icon = found_icon
			elif det_node is TextureRect:
				if found_icon:
					det_node.texture = found_icon
			else:
				var det_label = det_node.get_node_or_null("Label")
				if det_label is Label:
					det_label.text = "%d / %d" % [current_quantity, num_obj]
				elif det_node.has_method("set_text"):
					det_node.set_text("%d / %d" % [current_quantity, num_obj])
				
				var det_icon = det_node.get_node_or_null("Icon") if det_node.has_node("Icon") else det_node.get_node_or_null("TextureRect")
				if det_icon is TextureRect and found_icon:
					det_icon.texture = found_icon
				elif det_node is BaseButton and found_icon:
					det_node.icon = found_icon
						
		if mon_node:
			if mon_node is Label:
				mon_node.text = str(money_cost)
			elif mon_node is Button:
				mon_node.text = str(money_cost)
			else:
				var mon_label = mon_node.get_node_or_null("Label")
				if mon_label is Label:
					mon_label.text = str(money_cost)

		if is_purchased:
			if lbl_name is Label:
				lbl_name.text = str(car_item["Name"])
			if btn_sell is Button:
				btn_sell.text = "Купити"
				btn_sell.icon = null
				btn_sell.disabled = true
			item_node.disabled = true
			_set_elements_transparent(det_node, true)
			_set_elements_transparent(mon_node, true)
			previous_purchased = true
		else:
			if previous_purchased:
				if lbl_name is Label:
					lbl_name.text = str(car_item["Name"])
					
				if btn_sell is Button:
					btn_sell.text = "Купити"
					btn_sell.disabled = false
					if not btn_sell.pressed.is_connected(_on_upgrade_pressed.bind(car_item, item_node)):
						btn_sell.pressed.connect(_on_upgrade_pressed.bind(car_item, item_node))
				
				if not item_node.pressed.is_connected(_on_upgrade_pressed.bind(car_item, item_node)):
					item_node.pressed.connect(_on_upgrade_pressed.bind(car_item, item_node))
					
				item_node.disabled = false
				_set_elements_transparent(det_node, false)
				_set_elements_transparent(mon_node, false)
				previous_purchased = false
			else:
				if lbl_name is Label:
					lbl_name.text = "Заблоковано"
				if btn_sell is Button:
					btn_sell.text = "Недоступно"
					btn_sell.disabled = true
					btn_sell.icon = null
				item_node.disabled = true
				_set_elements_transparent(det_node, true)
				_set_elements_transparent(mon_node, true)
				previous_purchased = false
		
		level_grid.add_child(item_node)

func _set_elements_transparent(node: Node, transparent: bool) -> void:
	if not node:
		return
	var alpha = 0.0 if transparent else 1.0
	
	if node is CanvasItem:
		node.modulate.a = alpha
		
	for child in node.get_children():
		if child is CanvasItem:
			child.modulate.a = alpha

func _find_scene_icon_by_id(target_id: String) -> Texture2D:
	for cat in CATEGORIES:
		for rar in RARITIES:
			var node_path = "%s/%s" % [cat, rar]
			var obj_node = get_node_or_null(node_path)
			if not obj_node:
				continue
				
			var id_node = obj_node.get_node_or_null("ID")
			if id_node and id_node is Label and id_node.text.strip_edges() == target_id.strip_edges():
				if obj_node is BaseButton:
					return obj_node.icon
				else:
					var inner_btn = obj_node.get_node_or_null("Button")
					if inner_btn and inner_btn is BaseButton:
						return inner_btn.icon
					var inner_icon = obj_node.get_node_or_null("Icon")
					if inner_icon and inner_icon is TextureRect:
						return inner_icon.texture
					elif inner_icon and inner_icon is Button:
						return inner_icon.icon
	return null

func _on_upgrade_pressed(car_item: Dictionary, item_node: Button) -> void:
	var type_obj = str(car_item["TypeObj"])
	var num_obj = int(car_item["NumObj"])
	var money_cost = int(car_item["Money"])
	var car_id = car_item["ID"]
	
	db.query("SELECT Quantity FROM Objects WHERE Name = '%s';" % [type_obj])
	var obj_result = db.query_result
	if obj_result.is_empty():
		return
		
	var current_quantity = int(obj_result[0]["Quantity"])
	
	if current_quantity >= num_obj and GameManager.get_player_money() >= money_cost:
		db.query("UPDATE Objects SET Quantity = Quantity - %d WHERE Name = '%s';" % [num_obj, type_obj])
		GameManager.spend_money(money_cost)
		db.query("UPDATE Car SET Purchased = 1 WHERE ID = %d;" % [car_id])
		
		print("Успешное улучшение: ", car_item["Name"])
		refresh_car_upgrades()
	else:
		print("Недостаточно ресурсов или денег для улучшения!")
