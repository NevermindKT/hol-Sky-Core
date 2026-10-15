extends Node

@onready var MapButton: Button = $MapButton
@onready var TurretButton: Button = $TurretButton
@onready var CarButton: Button = $CarButton
@onready var InventoryButton: Button = $InventoryButton
@onready var ShopButton: Button = $ShopButton

@export_file("*.tscn") var map_scene_path: String
@export_file("*.tscn") var turret_scene_path: String
@export_file("*.tscn") var car_scene_path: String
@export_file("*.tscn") var inventory_scene_path: String
@export_file("*.tscn") var shop_scene_path: String

func _ready() -> void:
	MapButton.pressed.connect(MapButtonPressed)
	TurretButton.pressed.connect(TurretButtonPressed)
	CarButton.pressed.connect(CarButtonPressed)
	InventoryButton.pressed.connect(InventoryButtonPressed)
	ShopButton.pressed.connect(ShopButtonPressed)


func MapButtonPressed() -> void:
	print("Нажата кнопка: MapButton")
	get_tree().change_scene_to_file(map_scene_path)

func TurretButtonPressed() -> void:
	print("Нажата кнопка: TurretButton")
	get_tree().change_scene_to_file(turret_scene_path)

func CarButtonPressed() -> void:
	print("Нажата кнопка: CarButton")
	get_tree().change_scene_to_file(car_scene_path)

func InventoryButtonPressed() -> void:
	print("Нажата кнопка: InventoryButton")
	get_tree().change_scene_to_file(inventory_scene_path)

func ShopButtonPressed() -> void:
	print("Нажата кнопка: ShopButton")
	get_tree().change_scene_to_file(shop_scene_path)
