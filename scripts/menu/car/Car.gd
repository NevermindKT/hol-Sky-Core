extends Control

@onready var level_grid: VBoxContainer = $LevelGrid
@onready var template_level: Button = $LevelObj

@export var type_object_label: Label
@export var btn_previous: Button
@export var btn_next: Button
@export var part_image: Button
@export var part_icons: Control

const TYPES = ["Шини", "Двері", "Двигун", "Підвіска", "Передня рама"]
var current_type_index: int = 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if template_level:
		template_level.visible = false

	if btn_previous and not btn_previous.pressed.is_connected(_on_previous_pressed):
		btn_previous.pressed.connect(_on_previous_pressed)

	if btn_next and not btn_next.pressed.is_connected(_on_next_pressed):
		btn_next.pressed.connect(_on_next_pressed)

	Settings.language_changed.connect(update_type_display)
	BaseInventoryManager.money_changed.connect(_on_money_changed)
	BaseInventoryManager.inventory_changed.connect(refresh_car_upgrades)

	update_type_display()


func _on_previous_pressed() -> void:
	current_type_index = (current_type_index - 1 + TYPES.size()) % TYPES.size()
	update_type_display()


func _on_next_pressed() -> void:
	current_type_index = (current_type_index + 1) % TYPES.size()
	update_type_display()


func update_type_display() -> void:
	var type_name: String = TYPES[current_type_index]

	if type_object_label:
		type_object_label.text = tr(type_name)

	if part_image:
		part_image.icon = _find_part_icon(type_name)

	refresh_car_upgrades()


func _find_part_icon(type_name: String) -> Texture2D:
	if not part_icons:
		return null

	for child in part_icons.get_children():
		if child is Button and child.text == type_name:
			return child.icon

	return null


func refresh_car_upgrades() -> void:
	if not level_grid or not template_level:
		return

	for child in level_grid.get_children():
		child.queue_free()

	var target_type: String = TYPES[current_type_index]
	var car_items: Array = BaseInventoryManager.get_car_upgrades(target_type)
	var previous_purchased := true

	for car_item in car_items:
		var item_node := template_level.duplicate() as Button
		item_node.visible = true
		item_node.custom_minimum_size = template_level.size
		item_node.focus_mode = Control.FOCUS_NONE
		item_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var lbl_level := item_node.get_node("Level/Level") as Label
		var lbl_name := item_node.get_node("Level/Name") as Label
		var btn_res := item_node.get_node("Level/Det") as Button
		var btn_money := item_node.get_node("Level/Mon") as Button
		var btn_buy := item_node.get_node("Level/Sell") as Button

		lbl_level.text = str(int(car_item.get("Level", 0)))

		var object_item: Dictionary = BaseInventoryManager.find_object_by_name(
			str(car_item.get("TypeObj", ""))
		)
		var current_quantity := int(object_item.get("Quantity", 0))
		var num_obj := int(car_item.get("NumObj", 0))
		var money_cost := int(car_item.get("Money", 0))
		var is_purchased := int(car_item.get("Purchased", 0)) == 1
		var is_available := not is_purchased and previous_purchased

		if is_purchased or is_available:
			lbl_name.text = tr(str(car_item.get("Name", "")))
			btn_res.icon = _load_icon(str(object_item.get("IconPath", "")))
			btn_res.text = "%d/%d" % [current_quantity, num_obj]
			btn_money.text = str(money_cost)
		else:
			lbl_name.text = tr("Заблоковано")
			btn_res.text = ""
			btn_money.text = ""
			btn_money.icon = null

		if is_purchased:
			btn_buy.text = tr("Куплено")
			btn_buy.disabled = true
			btn_res.visible = false
			btn_money.visible = false
		elif is_available:
			btn_buy.text = tr("Придбати")
			btn_buy.disabled = (
				object_item.is_empty()
				or current_quantity < num_obj
				or BaseInventoryManager.get_player_money() < money_cost
			)
			btn_buy.pressed.connect(_on_upgrade_pressed.bind(car_item))
		else:
			btn_buy.text = "???"
			btn_buy.disabled = true
			item_node.disabled = true

		previous_purchased = is_purchased
		level_grid.add_child(item_node)


func _load_icon(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null

	return load(path) as Texture2D


func _on_money_changed(_amount: int) -> void:
	refresh_car_upgrades()


func _on_upgrade_pressed(car_item: Dictionary) -> void:
	if not BaseInventoryManager.purchase_car_upgrade(car_item):
		GameLog.print("Car upgrade not bought: ", car_item.get("Name", ""))

	refresh_car_upgrades()
