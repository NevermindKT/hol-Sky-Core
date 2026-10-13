extends Node

@onready var MapButton: Button = $MapButton
@onready var TurretButton: Button = $TurretButton
@onready var CarButton: Button = $CarButton
@onready var InventoryButton: Button = $InventoryButton
@onready var ShopButton: Button = $ShopButton

func _ready() -> void:
	MapButton.pressed.connect(MapButtonPressed)
	TurretButton.pressed.connect(TurretButtonPressed)
	CarButton.pressed.connect(CarButtonPressed)
	InventoryButton.pressed.connect(InventoryButtonPressed)
	ShopButton.pressed.connect(ShopButtonPressed)

func MapButtonPressed() -> void:
	print("Нажата кнопка: MapButton")
	get_tree().change_scene_to_file("res://map/Map.tscn")

func TurretButtonPressed() -> void:
	print("Нажата кнопка: TurretButton")
	get_tree().change_scene_to_file("res://turret/Turret.tscn")

func CarButtonPressed() -> void:
	print("Нажата кнопка: CarButton")
	get_tree().change_scene_to_file("res://car/Car.tscn")

func InventoryButtonPressed() -> void:
	print("Нажата кнопка: InventoryButton")
	get_tree().change_scene_to_file("res://inventory/Inventory.tscn")

func ShopButtonPressed() -> void:
	print("Нажата кнопка: ShopButton")
	get_tree().change_scene_to_file("res://shop/Shop.tscn")
