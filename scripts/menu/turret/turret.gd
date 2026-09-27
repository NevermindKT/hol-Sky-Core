extends Control

@onready var trees_container = $Trees 
@onready var money_label: Label = $Header/Header/HeaderButtons/Money/MoneyEquals

var db: SQLite = null

func _ready() -> void:
	_init_database()
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
		# Исправлено: используем метод get_player_money() вместо прямой переменной
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

	# Сохраняем в словарь для быстрого поиска по ID
	var turret_dict = {}
	for t in turrets:
		turret_dict[int(t["ID"])] = t

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
	var item_id = int(data["ID"])
	var purchased = int(data.get("Purchased", 0)) == 1
	var name_text = str(data.get("Name", ""))
	var emount_val = str(data.get("Emount", ""))
	
	# Логика разблокировки по вашим правилам
	var is_unlocked = false
	if item_id in [201, 301, 401]:
		is_unlocked = true
	else:
		var base_prefix = item_id / 100 * 100 
		var base_starter_id = base_prefix + 1 # 201, 301 или 401
		
		var starter_purchased = false
		if turret_dict.has(base_starter_id):
			starter_purchased = int(turret_dict[base_starter_id].get("Purchased", 0)) == 1
		
		# Промежуточные объекты (x10, x11) доступны после покупки базового x01
		if item_id % 100 in [10, 11]:
			if starter_purchased:
				is_unlocked = true
				
		# Объекты верхнего уровня (x21) разблокированы только если куплен соответствующий x11
		elif item_id % 100 == 21:
			var required_x11 = base_prefix + 11 
			var x11_purchased = false
			if turret_dict.has(required_x11):
				x11_purchased = int(turret_dict[required_x11].get("Purchased", 0)) == 1
			if x11_purchased:
				is_unlocked = true

	# Меняем текст и статус кнопки, НЕ затрагивая ее стиль и иконки
	if node is Button:
		# Очищаем старые соединения, чтобы избежать многократного вызова покупки при обновлении
		if node.is_connected("pressed", Callable(self, "_on_turret_pressed")):
			node.pressed.disconnect(_on_turret_pressed)

		if purchased:
			# Если объект уже куплен, выводим Name и "Куплено" в две строки
			node.text = name_text + "\nКуплено"
			node.disabled = false 
		elif is_unlocked:
			# Если разблокирован, но не куплен: Name на первой строке, Emount на второй
			node.text = name_text + "\n" + emount_val
			node.disabled = false
			
			# Подключаем безопасную покупку
			node.pressed.connect(_on_turret_pressed.bind(item_id, int(data.get("Emount", 0))))
		else:
			# Если заблокировано — текст кнопки "Заблоковано"
			node.text = "Заблоковано"
			node.disabled = true

# Покупка объекта с защитой от повторного списания
func _on_turret_pressed(item_id: int, price: int) -> void:
	if not db:
		_init_database()

	# Дополнительная проверка базы данных перед списанием на случай багов
	db.query("SELECT Purchased FROM Turret WHERE ID = %d;" % item_id)
	if not db.query_result.is_empty():
		if int(db.query_result[0]["Purchased"]) == 1:
			print("Этот объект уже куплен!")
			refresh_turrets()
			return

	# Списываем деньги через GameManager (метод spend_money уже корректно работает с базой данных)
	if GameManager.spend_money(price):
		db.query("UPDATE Turret SET Purchased = 1 WHERE ID = %d;" % item_id)
		print("Успешная покупка объекта ID: ", item_id)
		refresh_turrets()
	else:
		print("Недостаточно денег в GameManager!")
