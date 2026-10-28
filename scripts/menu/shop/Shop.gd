extends Control

@onready var boost_obj_container: HBoxContainer = $Items/BoostObj
@onready var bullet_obj_container: HBoxContainer = $Items/BulletObj
@onready var car_obj_container: HBoxContainer = $Items/CarObj
@onready var bubble_sweet_container: Control = $Bubble/SweetObj

@export var money_label: Label
@export var timer_label: Label

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
        BaseInventoryManager.current_shop_data["boost"] = BaseInventoryManager.generate_category_data_from_templates(boost_templates, 7)
        BaseInventoryManager.current_shop_data["bullet"] = BaseInventoryManager.generate_category_data_from_templates(bullet_templates, 7)
        BaseInventoryManager.current_shop_data["car"] = BaseInventoryManager.generate_category_data_from_templates(car_templates, 7)
        BaseInventoryManager.current_shop_data["sweet"] = BaseInventoryManager.generate_sweet_data_from_templates([boost_templates, bullet_templates, car_templates])

    _clear_container(boost_obj_container)
    _clear_container(bullet_obj_container)
    _clear_container(car_obj_container)
    _clear_container(bubble_sweet_container)

    if money_label:
        money_label.text = str(BaseInventoryManager.get_player_money())

    if BaseInventoryManager.current_shop_data.has("boost"):
        _render_category_items(BaseInventoryManager.current_shop_data["boost"], boost_templates, boost_obj_container)
    if BaseInventoryManager.current_shop_data.has("bullet"):
        _render_category_items(BaseInventoryManager.current_shop_data["bullet"], bullet_templates, bullet_obj_container)
    if BaseInventoryManager.current_shop_data.has("car"):
        _render_category_items(BaseInventoryManager.current_shop_data["car"], car_templates, car_obj_container)
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

    if BaseInventoryManager.is_purchased(data["unique_key"]):
        _apply_sold_out_state(shop_item, name_node, desc_node)
    else:
        if desc_node:
            shop_item.mouse_entered.connect(func():
                var is_sold = (name_node and name_node.text == tr("Sold Out")) or (shop_item is BaseButton and shop_item.disabled)
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
    var item_id := str(data.get("id", ""))
    var unique_key: String = str(data.get("unique_key", ""))
    var price := int(data.get("price", 0))

    # Находим предмет в JSON
    var inventory_item = BaseInventoryManager.find_object_by_id(item_id)

    if inventory_item.is_empty():
        push_warning("Предмет с ID %s не найден в objects.json" % item_id)
        return

    # Проверяем, что предмет ещё не куплен
    if BaseInventoryManager.is_purchased(unique_key):
        return

    # Списываем деньги
    if not BaseInventoryManager.spend_money(price):
        print("Недостаточно средств!")
        return

    # Увеличиваем количество предмета в инвентаре
    inventory_item["Quantity"] = int(inventory_item.get("Quantity", 0)) + 1

    # Сохраняем изменения в JSON
    BaseInventoryManager.save_data()

    # Помечаем товар как купленный
    BaseInventoryManager.mark_as_purchased(unique_key)

    if money_label:
        money_label.text = str(BaseInventoryManager.get_player_money())

    _apply_sold_out_state(shop_item, name_node, desc_node)

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
        name_node.text = tr("Sold Out")
    if desc_node is Label:
        desc_node.modulate.a = 0.0
