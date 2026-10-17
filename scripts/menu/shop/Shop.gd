extends Control

@onready var boost_obj_container: HBoxContainer = $Items/BoostObj
@onready var bullet_obj_container: HBoxContainer = $Items/BulletObj
@onready var car_obj_container: HBoxContainer = $Items/CarObj
@onready var bubble_sweet_container: Control = $Bubble/SweetObj

@export var money_label: Label
@onready var timer_label: Label = $Background/Timerr/TimerLabel/Timer

# Элементы панели описания товара (рамка всегда видна)
@onready var info_panel: Control = $Background/ObjDescription
@onready var info_name_label: Label = $Background/ObjDescription/Name
@onready var info_rarity_label: Label = $Background/ObjDescription/Rarity
@onready var info_desc_label: Label = $Background/ObjDescription/Description

# =========================================================================
# ⏱️ ВЫ МОЖЕТЕ ИЗМЕНИТЬ ЭТО ЧИСЛО, ЧТОБЫ УДЛИННИТЬ ИЛИ УКОРОТИТЬ ВРЕМЯ ТАЙМЕРА
# =========================================================================
@export var shop_refresh_duration: float = 10.0

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

	# Рамка описания теперь всегда видна с самого начала
	if info_panel:
		info_panel.visible = true

	if GameManager.shop_time_left <= 0.0:
		GameManager.shop_time_left = shop_refresh_duration

	if not GameManager.shop_refreshed.is_connected(_on_game_manager_shop_refreshed):
		GameManager.shop_refreshed.connect(_on_game_manager_shop_refreshed)

	if not GameManager.money_changed.is_connected(_on_money_changed):
		GameManager.money_changed.connect(_on_money_changed)

	render_shop()
	update_timer_display()

func _init_database() -> void:
	db = SQLite.new()
	db.path = "res://objects.db"
	db.open_db()

func _process(_delta: float) -> void:
	update_timer_display()

func update_timer_display() -> void:
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

	var price_node = shop_item.get_node_or_null("Emount")
	if price_node is Label or price_node is Button:
		price_node.text = str(data["price"])

	var icon_node = shop_item.get_node_or_null("Icon")
	if icon_node is TextureRect and data["icon"] != "":
		icon_node.texture = load(data["icon"])

	if GameManager.is_purchased(data["unique_key"]):
		_apply_sold_out_state(shop_item, name_node, price_node)
	else:
		_setup_hover_scale_effect(shop_item, price_node, icon_node, data)

		if shop_item is BaseButton:
			shop_item.pressed.connect(func(): _buy_item(data, shop_item, name_node, price_node))
		else:
			shop_item.mouse_filter = Control.MOUSE_FILTER_STOP
			shop_item.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_buy_item(data, shop_item, name_node, price_node)
			)

	target_container.add_child(shop_item)

func _setup_hover_scale_effect(item_node: Control, price_node: Node, icon_node: Node, data: Dictionary) -> void:
	if item_node.has_meta("hover_effect_initialized"):
		return
	item_node.set_meta("hover_effect_initialized", true)
	
	item_node.pivot_offset = item_node.size / 2.0
	
	if price_node is Control:
		price_node.pivot_offset = price_node.size / 2.0
		item_node.set_meta("price_node", price_node)
		
	if icon_node is Control:
		item_node.set_meta("icon_node", icon_node)
		item_node.set_meta("base_icon_pos", icon_node.position)
	
	var initial_color = item_node.modulate
	initial_color.a = 1.0
	item_node.modulate = initial_color
	
	if not item_node.mouse_entered.is_connected(_on_shop_item_mouse_entered.bind(item_node, data)):
		item_node.mouse_entered.connect(_on_shop_item_mouse_entered.bind(item_node, data))
		item_node.mouse_exited.connect(_on_shop_item_mouse_exited.bind(item_node))

func _on_shop_item_mouse_entered(item_node: Control, data: Dictionary) -> void:
	var current_color = item_node.modulate
	current_color.a = 1.0
	item_node.modulate = current_color
	
	if info_name_label:
		info_name_label.text = str(data.get("name", ""))
	if info_rarity_label:
		info_rarity_label.text = str(data.get("rarity", ""))
	if info_desc_label:
		info_desc_label.text = str(data.get("desc", ""))
	
	var tween = item_node.create_tween().set_parallel(true)
	tween.tween_property(item_node, "scale", Vector2(1.08, 1.08), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	if item_node.has_meta("icon_node"):
		var i_node = item_node.get_meta("icon_node") as Control
		var base_i_pos = item_node.get_meta("base_icon_pos") as Vector2
		if i_node and is_instance_valid(i_node):
			tween.tween_property(i_node, "position:y", base_i_pos.y - 20.0, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	if item_node.has_meta("price_node"):
		var p_node = item_node.get_meta("price_node") as Control
		if p_node and is_instance_valid(p_node):
			tween.tween_property(p_node, "scale", Vector2(0.925, 0.925), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _on_shop_item_mouse_exited(item_node: Control) -> void:
	var current_color = item_node.modulate
	current_color.a = 1.0
	item_node.modulate = current_color
	
	# Больше не скрываем info_panel при уводе мыши, рамка остается на месте
	
	var tween = item_node.create_tween().set_parallel(true)
	tween.tween_property(item_node, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	if item_node.has_meta("icon_node"):
		var i_node = item_node.get_meta("icon_node") as Control
		var base_i_pos = item_node.get_meta("base_icon_pos") as Vector2
		if i_node and is_instance_valid(i_node):
			tween.tween_property(i_node, "position:y", base_i_pos.y, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	if item_node.has_meta("price_node"):
		var p_node = item_node.get_meta("price_node") as Control
		if p_node and is_instance_valid(p_node):
			tween.tween_property(p_node, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _buy_item(data: Dictionary, shop_item: Control, name_node: Node, price_node: Node) -> void:
	if GameManager.is_purchased(data["unique_key"]):
		return

	if GameManager.spend_money(data["price"]):
		GameManager.mark_as_purchased(data["unique_key"])
		db.query("UPDATE Objects SET Quantity = Quantity + 1 WHERE ID = '%s';" % [data["id"]])
		
		if money_label:
			money_label.text = str(GameManager.get_player_money())

		_apply_sold_out_state(shop_item, name_node, price_node)
	else:
		print("Недостаточно средств!")

func _apply_sold_out_state(shop_item: Control, name_node: Node, price_node: Node) -> void:
	if shop_item is BaseButton:
		shop_item.disabled = false 
	
	shop_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	shop_item.scale = Vector2(1.0, 1.0)
	
	if item_has_icon_node(shop_item):
		var i_node = shop_item.get_meta("icon_node") as Control
		var base_i_pos = shop_item.get_meta("base_icon_pos") as Vector2
		if i_node and is_instance_valid(i_node):
			i_node.position = base_i_pos
			
	if price_node is Control:
		price_node.scale = Vector2(1.0, 1.0)
	
	if name_node is Label or name_node is Button:
		name_node.text = "Sold Out"
		
	if price_node is Label or price_node is Button:
		price_node.text = "Продано"

func item_has_icon_node(item_node: Control) -> bool:
	return item_node.has_meta("icon_node")
