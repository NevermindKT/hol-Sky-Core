extends Control

@export_category("Footer")
@export var footer: Footer

@export_category("Menus")

@export var car: Control
@export var map: Control
@export var shop: Control
@export var turret: Control
@export var inventory: Control


func _ready() -> void:
	if GameState.needs_intro():
		hide()
		GameFlow.enter_base.call_deferred()
		return
	GameState.enter_base()
	MenuMusic.set_base_tab(&"map")
	footer.MapButton.pressed.connect(_map_button_pressed)
	footer.CarButton.pressed.connect(_car_button_pressed)
	footer.ShopButton.pressed.connect(_shop_button_pressed)
	footer.TurretButton.pressed.connect(_turret_button_pressed)
	footer.InventoryButton.pressed.connect(_inventory_button_pressed)


func _show_menu(selected_menu: Control) -> void:
	_hide_all()
	selected_menu.show()


func _map_button_pressed() -> void:
	_show_menu(map)
	MenuMusic.set_base_tab(&"map")


func _turret_button_pressed() -> void:
	_show_menu(turret)
	MenuMusic.set_base_tab(&"turret")


func _car_button_pressed() -> void:
	_show_menu(car)
	MenuMusic.set_base_tab(&"car")


func _inventory_button_pressed() -> void:
	_show_menu(inventory)
	MenuMusic.set_base_tab(&"inventory")


func _shop_button_pressed() -> void:
	_show_menu(shop)
	MenuMusic.set_base_tab(&"shop")


func _hide_all():
	car.hide()
	map.hide()
	shop.hide()
	turret.hide()
	inventory.hide()
