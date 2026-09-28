extends Control

@onready var boost_obj_container: HBoxContainer = $BoostItems/BoostObj
@onready var bullet_obj_container: HBoxContainer = $BulletItems/BulletObj
@onready var car_obj_container: HBoxContainer = $CarItems/CarObj
@onready var bubble_sweet_container: Control = $Bubble/SweetObj

@export var money_label: Label
@export var timer_label: Label

var db: SQLite = null

@onready var boost_templates = {
	"Common": $Boost/Common,
	"Uncommon": $Boost/Uncommon,
	"Rare": $Boost/Rare,
	"Epic": $Boost/Epic,
	"Legendary": $Boost/Legendary
}

@onready var bullet_templates = {
	"Common": $Bullet/Common,
	"Uncommon": $Bullet/Uncommon,
	"Rare": $Bullet/Uncommon,
	"Epic": $Bullet/Epic,
	"Legendary": $Bullet/Legendary if has_node("$Bullet/Legendary") else $Bullet/Epic
}

@onready var car_templates = {
	"Common": $Car/Common,
	"Uncommon": $Car/Uncommon,
	"Rare": $Car/Uncommon,
	"Epic": $Car/Epic,
	"Legendary": $Car/Legendary
}

@onready var clerks: Array = [
	get_node_or_null("Clerk1"),
	get_node_or_null("Clerk2"),
	get_node_or_null("Clerk3")
]

func _ready() -> void:
	_init_database()

	if not GameManager.shop_refreshed.is_connected(_on_game_manager_shop_refreshed):
		GameManager.shop_refreshed.connect(_on_game_manager_shop_refreshed)

	if not GameManager.money_changed.is_connected(_on_money_changed):
		GameManager.money_changed.connect(_on_money_changed)

	render_shop()

func _init_database() -> void:
	db = SQLite.new()
	db.path = "res://objects.db"
	db.open_db()

func _process(_delta: float) -> void:
	if timer_label:
		var time_left = max(0.0, GameManager.shop_time_left)
		var minutes = int(time_left) / 60
		var seconds = int(time_left) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_game_manager_shop_refreshed() -> void:
	render_shop()

func _on_money_changed(new_amount: int) -> void:
	if money_label:
		money_label.text = str(new_amount)

func render_shop() -> void:
	if GameManager.current_shop_data.is_empty():
		GameManager.current_shop_data["boost"] = GameManager.generate_category_data_from_templates(boost_templates, 7)
		GameManager.current_shop_data["bullet"] = GameManager.generate_category_data_from_templates(bullet_templates, 7)
		GameManager.current_shop_data["car"] = GameManager.generate_category_data_from_templates(car_templates, 7)
		GameManager.current_shop_data["sweet"] = GameManager.generate_sweet_data_from_templates([boost_templates, bullet_templates, car_templates])

	_clear_container(boost_obj_container)
	_clear_container(bullet_obj_container)
	_clear_container(car_obj_container)
	_clear_container(bubble_sweet_container)

	if money_label:
		money_label.text = str(GameManager.get_player_money())

	if GameManager.current_shop_data.has("boost"):
		_render_category_items(GameManager.current_shop_data["boost"], boost_templates, boost_obj_container)
	if GameManager.current_shop_data.has("bullet"):
		_render_category_items(GameManager.current_shop_data["bullet"], bullet_templates, bullet_obj_container)
	if GameManager.current_shop_data.has("car"):
		_render_category_items(GameManager.current_shop_data["car"], car_templates, car_obj_container)
	if GameManager.current_shop_data.has("sweet"):
		_render_sweet_item(GameManager.current_shop_data["sweet"])
		
	_update_clerks()

func _clear_container(container: Control) -> void:
	if container:
		for child in container.get_children():
			child.queue_free()

func _update_clerks() -> void:
	if clerks.is_empty():
		return
	
	var current_clerk_index = GameManager.active_clerk_index
	
	for i in range(clerks.size()):
		var clerk = clerks[i]
		if clerk is CanvasItem:
			if i == current_clerk_index:
				clerk.visible = true
				clerk.modulate.a = 1.0
			else:
				clerk.visible = false
				clerk.modulate.a = 0.0

func _render_category_items(items_data: Array, templates: Dictionary, target_container: Control) -> void:
	if not target_container: return
	for item_data in items_data:
		_create_card_from_data(item_data, templates, target_container)

func _render_sweet_item(data: Dictionary) -> void:
	if data.is_empty() or not bubble_sweet_container: return
	_create_card_from_data(data, boost_templates, bubble_sweet_container)

func _create_card_from_data(data: Dictionary, templates: Dictionary, target_container: Control) -> void:
	var rarity_key = data.get("rarity", "Common")
	var template_node = templates.get(rarity_key, templates["Common"])
	if not template_node: return

	var shop_item = template_node.duplicate() as Control
	shop_item.visible = true

	var id_node = shop_item.get_node_or_null("ID")
	if id_node: 
		id_node.text = str(data["id"])

	var name_node = shop_item.get_node_or_null("Name")
	if name_node is Label or name_node is Button: 
		name_node.text = str(data["name"])

	var desc_node = shop_item.get_node_or_null("Description")
	if desc_node is Label:
		desc_node.text = str(data["desc"])
		desc_node.modulate.a = 0.0

	var price_node = shop_item.get_node_or_null("Emount")
	if price_node is Label or price_node is Button:
		price_node.text = str(data["price"])

	var icon_node = shop_item.get_node_or_null("Icon")
	if icon_node is TextureRect and data["icon"] != "":
		icon_node.texture = load(data["icon"])

	if GameManager.is_purchased(data["unique_key"]):
		_apply_sold_out_state(shop_item, name_node, desc_node)
	else:
		if desc_node:
			shop_item.mouse_entered.connect(func():
				var is_sold = (name_node and name_node.text == "Sold Out") or (shop_item is BaseButton and shop_item.disabled)
				if not is_sold:
					desc_node.modulate.a = 1.0
			)
			shop_item.mouse_exited.connect(func():
				desc_node.modulate.a = 0.0
			)

		if shop_item is BaseButton:
			shop_item.pressed.connect(func(): _buy_item(data, shop_item, name_node, desc_node))
		else:
			shop_item.mouse_filter = Control.MOUSE_FILTER_STOP
			shop_item.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_buy_item(data, shop_item, name_node, desc_node)
			)

	target_container.add_child(shop_item)

func _buy_item(data: Dictionary, shop_item: Control, name_node: Node, desc_node: Node) -> void:
	if GameManager.spend_money(data["price"]):
		GameManager.mark_as_purchased(data["unique_key"])
		db.query("UPDATE Objects SET Quantity = Quantity + 1 WHERE ID = '%s';" % [data["id"]])
		
		if money_label:
			money_label.text = str(GameManager.get_player_money())

		_apply_sold_out_state(shop_item, name_node, desc_node)
	else:
		print("Недостаточно средств!")

func _apply_sold_out_state(shop_item: Control, name_node: Node, desc_node: Node) -> void:
	if shop_item is BaseButton:
		var normal_style = shop_item.get_theme_stylebox("normal")
		var new_style: StyleBoxFlat
		if normal_style is StyleBoxFlat:
			new_style = normal_style.duplicate() as StyleBoxFlat
		else:
			new_style = StyleBoxFlat.new()
			if normal_style: new_style.bg_color = normal_style.bg_color
		
		new_style.bg_color = new_style.bg_color.darkened(0.2)
		new_style.set_corner_radius_all(10)
		shop_item.add_theme_stylebox_override("normal", new_style)
		shop_item.disabled = true
	else:
		shop_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if shop_item is Panel or shop_item is PanelContainer:
			var panel_style = shop_item.get_theme_stylebox("panel")
			var new_style: StyleBoxFlat
			if panel_style is StyleBoxFlat:
				new_style = panel_style.duplicate() as StyleBoxFlat
			else:
				new_style = StyleBoxFlat.new()
				if panel_style: new_style.bg_color = panel_style.bg_color
			
			new_style.bg_color = new_style.bg_color.darkened(0.2)
			new_style.set_corner_radius_all(10)
			shop_item.add_theme_stylebox_override("panel", new_style)
		else:
			shop_item.self_modulate = Color(0.8, 0.8, 0.8, 1.0)
			
	if name_node is Label or name_node is Button:
		name_node.text = "Sold Out"
	if desc_node is Label:
		desc_node.modulate.a = 0.0
