extends Control

@onready var level_grid: VBoxContainer = $LevelGrid
@onready var level_obj_panel: Panel = $LevelObj
@onready var template_level: HBoxContainer = $LevelObj/Level

# Новые элементы управления для выбора типов
@onready var type_object_label: Label = $Types/Selling/Object
@onready var btn_previous: Button = $Types/Selling/Previous
@onready var btn_next: Button = $Types/Selling/Next

var db: SQLite = null

const RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const TYPES = ["Шини", "Двері", "Двигун", "Підвіска", "Передня рама"]
var current_type_index: int = 0

func _ready() -> void:
	_init_database()
	if template_level:
		template_level.visible = false
		
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
	if type_object_label:
		type_object_label.text = TYPES[current_type_index]
	refresh_car_upgrades()

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
		if not template_level: break
		
		var item_node = template_level.duplicate() as Control
		item_node.visible = true
		
		var lbl_level = item_node.get_node_or_null("Level")
		if lbl_level is Label:
			lbl_level.text = str(car_item["Level"])
			
		var lbl_name = item_node.get_node_or_null("Name")
		var btn_sell = item_node.get_node_or_null("Sell")
		
		var type_obj = str(car_item["TypeObj"])
		db.query("SELECT * FROM Objects WHERE Name = '%s';" % [type_obj])
		var obj_result = db.query_result
		
		var current_quantity = 0
		var obj_id = ""
		if not obj_result.is_empty():
			current_quantity = int(obj_result[0]["Quantity"])
			obj_id = str(obj_result[0]["ID"])
			
		# Логика Purchased: 1 — куплено, 0 — не куплено
		var is_purchased = int(car_item.get("Purchased", 0)) == 1
		
		if is_purchased:
			if lbl_name is Label:
				lbl_name.text = str(car_item["Name"])
			if btn_sell is Button:
				btn_sell.text = "Куплено"
				btn_sell.icon = null
			previous_purchased = true
		else:
			if previous_purchased:
				if lbl_name is Label:
					lbl_name.text = str(car_item["Name"])
					
				var num_obj = int(car_item["NumObj"])
				var money_cost = int(car_item["Money"])
				
				if btn_sell is Button:
					btn_sell.text = "%d / %d + %d" % [current_quantity, num_obj, money_cost]
					if obj_id != "":
						var found_icon = _find_scene_icon_by_id(obj_id)
						if found_icon:
							btn_sell.icon = found_icon
					if not btn_sell.pressed.is_connected(_on_upgrade_pressed.bind(car_item, btn_sell)):
						btn_sell.pressed.connect(_on_upgrade_pressed.bind(car_item, btn_sell))
				previous_purchased = false
			else:
				if lbl_name is Label:
					lbl_name.text = "Заблоковано"
				if btn_sell is Button:
					btn_sell.text = "???"
					btn_sell.icon = null
				previous_purchased = false
		
		level_grid.add_child(item_node)

func _find_scene_icon_by_id(target_id: String) -> Texture2D:
	for rar in RARITIES:
		var node_path = "Car/%s" % [rar]
		var obj_node = get_node_or_null(node_path)
		if not obj_node:
			continue
			
		var id_node = obj_node.get_node_or_null("ID")
		if id_node and id_node is Label and id_node.text.strip_edges() == target_id:
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

func _on_upgrade_pressed(car_item: Dictionary, btn_sell: Button) -> void:
	var type_obj = str(car_item["TypeObj"])
	var num_obj = int(car_item["NumObj"])
	var money_cost = int(car_item["Money"])
	var car_id = car_item["ID"]
	
	db.query("SELECT Quantity FROM Objects WHERE Name = '%s';" % [type_obj])
	var obj_result = db.query_result
	if obj_result.is_empty():
		return
		
	var current_quantity = int(obj_result[0]["Quantity"])
	
	# Проверяем количество ресурсов в базе и деньги через GameManager.get_player_money()
	if current_quantity >= num_obj and GameManager.get_player_money() >= money_cost:
		# Списываем предметы (исправлена опечатка в SQL-запросе)
		db.query("UPDATE Objects SET Quantity = Quantity - %d WHERE Name = '%s';" % [num_obj, type_obj])
		
		# Списываем деньги через GameManager (метод сам обновит базу и вызовет сигнал money_changed)
		GameManager.spend_money(money_cost)
			
		# Меняем статус Purchased на 1 для текущего уровня
		db.query("UPDATE Car SET Purchased = 1 WHERE ID = %d;" % [car_id])
		
		print("Успешное улучшение: ", car_item["Name"])
		refresh_car_upgrades()
	else:
		print("Недостаточно ресурсов или денег для улучшения!")
