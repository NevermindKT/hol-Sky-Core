extends Control

@onready var trees_container = $Trees 
@onready var money_label: Label = $Header/Header/HeaderButtons/Money/MoneyEquals

# Элементы информационной панели согласно вашему пути
@onready var info_panel: Control = $Background/Info
@onready var info_icon: Button = $Background/Info/HBoxContainer/Icon
@onready var info_name_label: Label = $Background/Info/HBoxContainer/Name
@onready var info_emount_label: Label = $Background/Info/HBoxContainer/Name/Emount
@onready var btn_purchase: Button = $Background/Info/HBoxContainer/Purchase

var db: SQLite = null
var current_selected_id: int = -1
var current_item_price: int = 0

func _ready() -> void:
	_init_database()
	
	if info_panel:
		info_panel.visible = false # Скрываем панель информации при старте

	if btn_purchase and not btn_purchase.pressed.is_connected(_on_purchase_button_pressed):
		btn_purchase.pressed.connect(_on_purchase_button_pressed)

	refresh_turrets()
	
	if GameManager.has_signal("money_changed"):
		GameManager.money_changed.connect(_on_money_changed)
	update_money_display()

func _init_database() -> void:
	db = SQLite.new()
	db.path = "res://objects.db"
	db.open_db()

func update_money_display() -> void:
	if money_label:
		money_label.text = str(GameManager.get_player_money())

func _on_money_changed(new_amount: int) -> void:
	if money_label:
		money_label.text = str(new_amount)

# Главная функция обновления дерева объектов
func refresh_turrets() -> void:
	if not db:
		_init_database()

	db.query("SELECT * FROM Turret;")
	var turrets = db.query_result
	if turrets.is_empty():
		return

	var turret_dict = {}
	for t in turrets:
		turret_dict[int(t["ID"])] = t

	if trees_container:
		_update_tree_recursive(trees_container, turret_dict)
		
	# Если объект выбран, обновляем информацию в панели на лету
	if current_selected_id != -1 and turret_dict.has(current_selected_id):
		_show_turret_info(turret_dict[current_selected_id], find_node_by_id(trees_container, current_selected_id), turret_dict)

# Рекурсивный обход дерева узлов сцены
func _update_tree_recursive(parent_node: Node, turret_dict: Dictionary) -> void:
	for child in parent_node.get_children():
		if child.name.is_valid_int():
			var item_id = child.name.to_int()
			if turret_dict.has(item_id):
				var data = turret_dict[item_id]
				_configure_object_node(child, data, turret_dict)
		
		if child.get_child_count() > 0:
			_update_tree_recursive(child, turret_dict)

# Вспомогательная функция поиска узла по ID
func find_node_by_id(parent_node: Node, target_id: int) -> Control:
	for child in parent_node.get_children():
		if child.name.is_valid_int() and child.name.to_int() == target_id:
			return child
		if child.get_child_count() > 0:
			var found = find_node_by_id(child, target_id)
			if found:
				return found
	return null

# Общая логика определения разблокировки узла
func _check_is_unlocked(item_id: int, turret_dict: Dictionary) -> bool:
	if item_id in [201, 301, 401]:
		return true
	
	var base_prefix = item_id / 100 * 100 
	var base_starter_id = base_prefix + 1 
	
	var starter_purchased = false
	if turret_dict.has(base_starter_id):
		starter_purchased = int(turret_dict[base_starter_id].get("Purchased", 0)) == 1
	
	if item_id % 100 in [10, 11]:
		if starter_purchased:
			return true
	elif item_id % 100 == 21:
		var required_x11 = base_prefix + 11 
		var x11_purchased = false
		if turret_dict.has(required_x11):
			x11_purchased = int(turret_dict[required_x11].get("Purchased", 0)) == 1
		if x11_purchased:
			return true
			
	return false

# Настройка узла дерева (визуал, залочки, кликабельность)
func _configure_object_node(node: Node, data: Dictionary, turret_dict: Dictionary) -> void:
	var item_id = int(data["ID"])
	var purchased = int(data.get("Purchased", 0)) == 1
	var is_unlocked = _check_is_unlocked(item_id, turret_dict)

	# Управление видимостью замка (Lock): видно ТОЛЬКО если объект НЕ куплен и НЕ разблокирован
	var lock_node = node.get_node_or_null("Lock")
	
	if purchased:
		node.modulate = Color("bb9c78ff") # Затемняем купленный объект
		if lock_node:
			lock_node.visible = false 
	elif is_unlocked:
		node.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if lock_node:
			lock_node.visible = false 
	else:
		node.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if lock_node:
			lock_node.visible = true # Показываем замок, если заблокировано

	# Подключение клика для выбора элемента
	if node is BaseButton:
		if not node.pressed.is_connected(_on_turret_node_clicked.bind(data, node, turret_dict)):
			node.pressed.connect(_on_turret_node_clicked.bind(data, node, turret_dict))
	else:
		var btn = node.get_node_or_null("Button")
		if btn and btn is BaseButton:
			if not btn.pressed.is_connected(_on_turret_node_clicked.bind(data, node, turret_dict)):
				btn.pressed.connect(_on_turret_node_clicked.bind(data, node, turret_dict))
		elif not node.has_meta("click_connected"):
			node.set_meta("click_connected", true)
			var gui_detector = Button.new()
			gui_detector.flat = true
			gui_detector.set_anchors_and_presets(Control.PRESET_FULL_RECT)
			gui_detector.pressed.connect(_on_turret_node_clicked.bind(data, node, turret_dict))
			node.add_child(gui_detector)

# Клик по объекту в дереве
func _on_turret_node_clicked(data: Dictionary, node: Control, turret_dict: Dictionary) -> void:
	_show_turret_info(data, node, turret_dict)

func _show_turret_info(data: Dictionary, node: Control, turret_dict: Dictionary) -> void:
	current_selected_id = int(data["ID"])
	current_item_price = int(data.get("Emount", 0))
	var purchased = int(data.get("Purchased", 0)) == 1
	var is_unlocked = _check_is_unlocked(current_selected_id, turret_dict)

	if info_panel:
		info_panel.visible = true

	# Копируем иконку
	if info_icon:
		if node is BaseButton:
			info_icon.icon = node.icon
		else:
			var inner_btn = node.get_node_or_null("Button")
			if inner_btn and inner_btn is BaseButton:
				info_icon.icon = inner_btn.icon
			else:
				var tex_rect = node.get_node_or_null("Icon")
				if tex_rect and tex_rect is TextureRect and "texture" in info_icon:
					info_icon.texture = tex_rect.texture

	# Проверяем состояние доступности (если висит Lock / заблокировано)
	if not is_unlocked and not purchased:
		if info_name_label:
			info_name_label.text = "Недоступно"
			info_name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		if info_emount_label:
			info_emount_label.text = "???"
		if btn_purchase:
			btn_purchase.text = "Заблоковано"
			btn_purchase.disabled = true
	else:
		# Выводим нормальные данные, если разблокировано или куплено
		if info_name_label:
			info_name_label.text = str(data.get("Name", ""))
			# Если объект куплен -> Center, иначе -> Top
			if purchased:
				info_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			else:
				info_name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

		if info_emount_label:
			if purchased:
				info_emount_label.text = ""
			else:
				info_emount_label.text = str(current_item_price)

		if btn_purchase:
			if purchased:
				btn_purchase.text = "Куплено"
				btn_purchase.disabled = true
			else:
				btn_purchase.text = "Купити"
				btn_purchase.disabled = false

# Покупка выбранного товара через кнопку Purchase в панели Info с защитой от повторной покупки
func _on_purchase_button_pressed() -> void:
	if current_selected_id == -1:
		return

	if not db:
		_init_database()

	# Строгая проверка в базе данных перед покупкой (защита от повторной покупки по ID)
	db.query("SELECT Purchased FROM Turret WHERE ID = %d;" % current_selected_id)
	if not db.query_result.is_empty():
		if int(db.query_result[0]["Purchased"]) == 1:
			print("Этот объект уже куплен! Повторная покупка невозможна.")
			refresh_turrets()
			return

	if GameManager.spend_money(current_item_price):
		db.query("UPDATE Turret SET Purchased = 1 WHERE ID = %d;" % current_selected_id)
		print("Успешная покупка объекта ID: ", current_selected_id)
		refresh_turrets()
	else:
		print("Недостаточно денег в GameManager!")
