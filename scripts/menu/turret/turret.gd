extends Control

@onready var trees_container = $Trees 
#@onready var money_label: Label = $Header/Header/HeaderButtons/Money/MoneyEquals

func _ready() -> void:
	Settings.language_changed.connect(refresh_turrets)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	refresh_turrets()
	
	#if BaseInventoryManager.has_signal("money_changed"):
		#BaseInventoryManager.money_changed.connect(_on_money_changed)
	#update_money_display()


#func update_money_display() -> void:
	#if money_label:
		## Исправлено: используем метод get_player_money() вместо прямой переменной
		#money_label.text = str(BaseInventoryManager.get_player_money())
#
#func _on_money_changed(new_amount: int) -> void:
	#if money_label:
		#money_label.text = str(new_amount)

# Главная функция обновления дерева объектов
func refresh_turrets() -> void:
	var turrets: Array = BaseInventoryManager.get_rows("Turret")
	if turrets.is_empty():
		push_warning("Массив Turret не найден или пуст в objects.json")
		return

	var turret_dict: Dictionary = {}

	for turret in turrets:
		turret_dict[int(turret.get("ID", 0))] = turret

	if trees_container:
		_update_tree_recursive(trees_container, turret_dict)

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

# Настройка узла с учетом логики разблокировки, покупки и текста
func _configure_object_node(node: Node, data: Dictionary, turret_dict: Dictionary) -> void:
	var item_id := int(data.get("ID", 0))
	var purchased := int(data.get("Purchased", 0)) == 1
	var name_text := tr(str(data.get("Name", "")))
	var emount_val := str(data.get("Emount", ""))

	var is_unlocked := false

	if item_id in [201, 301, 401]:
		is_unlocked = true
	else:
		var base_prefix: int = int(item_id / 100) * 100
		var base_starter_id := base_prefix + 1

		var starter_purchased := false
		if turret_dict.has(base_starter_id):
			starter_purchased = int(
				turret_dict[base_starter_id].get("Purchased", 0)
			) == 1

		if item_id % 100 in [10, 11]:
			if starter_purchased:
				is_unlocked = true

		elif item_id % 100 == 21:
			var required_x11 := base_prefix + 11
			var x11_purchased := false

			if turret_dict.has(required_x11):
				x11_purchased = int(
					turret_dict[required_x11].get("Purchased", 0)
				) == 1

			if x11_purchased:
				is_unlocked = true

	if not node is Button:
		return

	var button := node as Button

	# Сохраняем актуальные данные для обработчика покупки.
	button.set_meta("turret_id", item_id)
	button.set_meta("turret_price", int(data.get("Emount", 0)))

	# Подключаем обработчик только один раз.
	if not button.pressed.is_connected(_on_turret_button_pressed.bind(button)):
		button.pressed.connect(_on_turret_button_pressed.bind(button))

	if purchased:
		button.text = name_text + "\n" + tr("Куплено")
		button.disabled = false
	elif is_unlocked:
		button.text = name_text + "\n" + emount_val
		button.disabled = false
	else:
		button.text = "Заблоковано"
		button.disabled = true

# Покупка объекта с защитой от повторного списания
func _on_turret_button_pressed(button: Button) -> void:
	var item_id := int(button.get_meta("turret_id", 0))
	var price := int(button.get_meta("turret_price", 0))

	# Повторно проверяем состояние объекта в JSON.
	var turret = BaseInventoryManager.find_row(
		"Turret", "ID", item_id
	)

	if turret.is_empty():
		push_warning("Объект Turret с ID %d не найден" % item_id)
		return

	if int(turret.get("Purchased", 0)) == 1:
		print("Этот объект уже куплен!")
		refresh_turrets()
		return

	# Сначала проверяем и списываем деньги.
	if not BaseInventoryManager.spend_money(price):
		print("Недостаточно денег в BaseInventoryManager!")
		return

	# Сохраняем покупку в objects.json.
	var updated = BaseInventoryManager.update_row(
		"Turret",
		"ID",
		item_id,
		{"Purchased": 1}
	)

	if not updated:
		# Если обновление не удалось, возвращаем деньги.
		BaseInventoryManager.add_money(price)
		push_error("Не удалось сохранить покупку Turret ID: %d" % item_id)
		return

	print("Успешная покупка объекта ID: ", item_id)
	refresh_turrets()
