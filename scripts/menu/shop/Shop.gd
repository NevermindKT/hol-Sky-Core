extends Control

@export var bubble_sweet_container: Control

@export var money_label: Label
@export var timer_label: Label

@export_category("Items")
@export var item_view_scene: PackedScene
@export var items_container: GridContainer


@onready var clerks: Array = [
	get_node_or_null("Clerk1"),
	get_node_or_null("Clerk2"),
	get_node_or_null("Clerk3")
]

func _ready() -> void:
	Settings.language_changed.connect(render_shop)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if not BaseInventoryManager.shop_refreshed.is_connected(_on_game_manager_shop_refreshed):
		BaseInventoryManager.shop_refreshed.connect(_on_game_manager_shop_refreshed)

	if not BaseInventoryManager.money_changed.is_connected(_on_money_changed):
		BaseInventoryManager.money_changed.connect(_on_money_changed)

	render_shop()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	if timer_label:
		var time_left = max(0.0, BaseInventoryManager.shop_time_left)
		var minutes = int(time_left / 60)
		var seconds = int(time_left) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]


func _on_game_manager_shop_refreshed() -> void:
	render_shop()


func _on_money_changed(new_amount: int) -> void:
	if money_label:
		money_label.text = str(new_amount)


func render_shop() -> void:
	if BaseInventoryManager.current_shop_data.is_empty():
		BaseInventoryManager.current_shop_data["boost"] = BaseInventoryManager.generate_category_data("Boost", 7)
		BaseInventoryManager.current_shop_data["bullet"] = BaseInventoryManager.generate_category_data("Bullet", 7)
		BaseInventoryManager.current_shop_data["car"] = BaseInventoryManager.generate_category_data("Car", 7)

	_clear_container(items_container)
	_clear_container(bubble_sweet_container)

	if money_label:
		money_label.text = str(BaseInventoryManager.get_player_money())

	for category in ["boost", "bullet", "car"]:
		if BaseInventoryManager.current_shop_data.has(category):
			_render_category_items(
				BaseInventoryManager.current_shop_data[category],
				items_container
			)

	if BaseInventoryManager.current_shop_data.has("sweet"):
		_render_sweet_item(BaseInventoryManager.current_shop_data["sweet"])

	_update_clerks()


func _clear_container(container: Control) -> void:
	if container:
		for child in container.get_children():
			child.queue_free()


func _update_clerks() -> void:
	if clerks.is_empty():
		return
	
	var current_clerk_index = BaseInventoryManager.active_clerk_index
	
	for i in range(clerks.size()):
		var clerk = clerks[i]
		if clerk is CanvasItem:
			if i == current_clerk_index:
				clerk.visible = true
				clerk.modulate.a = 1.0
			else:
				clerk.visible = false
				clerk.modulate.a = 0.0


func _render_category_items(items_data: Array, target_container: Control) -> void:
	if not target_container:
		return

	for item_data in items_data:
		_create_card_from_data(item_data, target_container)


func _render_sweet_item(data: Dictionary) -> void:
	if data.is_empty() or not bubble_sweet_container:
		return

	_create_card_from_data(data, bubble_sweet_container)


func _create_card_from_data(data: Dictionary, target_container: Control) -> void:
	if not item_view_scene:
		push_warning("Shop: item_view_scene не назначена.")
		return

	var shop_item := item_view_scene.instantiate() as item_view

	if not shop_item:
		push_warning("Shop: сцена не содержит скрипт item_view.")
		return

	# Подготавливаем данные для item_view.
	var item_data := {
		"id": str(data.get("id", "")),
		"icon": str(data.get("icon", "")),
		"price": int(data.get("price", 0)),
		"Quantity": 0
	}

	shop_item.setup(item_data)

	# Цена нужна в магазине, количество — нет.
	if shop_item.count_label:
		shop_item.count_label.visible = false

	if shop_item.price_label:
		shop_item.price_label.visible = true
		shop_item.price_label.text = str(data.get("price", 0))

	# Карточка товара становится видимой.
	shop_item.visible = true

	# Добавляем карточку в контейнер.
	target_container.add_child(shop_item)

	var unique_key := str(data.get("unique_key", ""))

	# В item_view пока нет отдельных узлов названия и описания,
	# поэтому состояние покупки применяем непосредственно к карточке.
	if BaseInventoryManager.is_purchased(unique_key):
		_apply_sold_out_state(shop_item, null, null)
	else:
		if shop_item.button:
			shop_item.button.pressed.connect(
				_buy_item.bind(data, shop_item)
			)


func _buy_item(data: Dictionary, shop_item: item_view) -> void:
	var item_id := str(data.get("id", ""))
	var unique_key := str(data.get("unique_key", ""))
	var price := int(data.get("price", 0))

	var inventory_item := BaseInventoryManager.find_object_by_id(item_id)

	if inventory_item.is_empty():
		push_warning("Предмет с ID %s не найден в objects.json" % item_id)
		return

	if BaseInventoryManager.is_purchased(unique_key):
		return

	if not BaseInventoryManager.spend_money(price):
		print("Недостаточно средств!")
		return

	inventory_item["Quantity"] = int(inventory_item.get("Quantity", 0)) + 1

	BaseInventoryManager.save_data()
	BaseInventoryManager.mark_as_purchased(unique_key)
	BaseInventoryManager.inventory_changed.emit()

	if money_label:
		money_label.text = str(BaseInventoryManager.get_player_money())

	_apply_sold_out_state(shop_item, null, null)


func _apply_sold_out_state(shop_item: Control, name_node: Node = null, desc_node: Node = null) -> void:
	if shop_item is item_view:
		if shop_item.button:
			shop_item.button.disabled = true
			shop_item.button.modulate = Color(0.6, 0.6, 0.6, 1.0)

		shop_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	if name_node is Label or name_node is Button:
		name_node.text = tr("Sold Out")

	if desc_node is Label:
		desc_node.modulate.a = 0.0
