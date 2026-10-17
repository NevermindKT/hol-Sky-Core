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
	var target_scene = "res://scenes/menu/map/Map.tscn"
	if get_tree().current_scene.scene_file_path == target_scene:
		print("Вы уже находитесь на этой сцене.")
		return
	get_tree().change_scene_to_file(target_scene)

func TurretButtonPressed() -> void:
	print("Нажата кнопка: TurretButton")
	var target_scene = "res://scenes/menu/turret/Turret.tscn"
	if get_tree().current_scene.scene_file_path == target_scene:
		print("Вы уже находитесь на этой сцене.")
		return
	get_tree().change_scene_to_file(target_scene)

func CarButtonPressed() -> void:
	print("Нажата кнопка: CarButton")
	var target_scene = "res://scenes/menu/car/Car.tscn"
	if get_tree().current_scene.scene_file_path == target_scene:
		print("Вы уже находитесь на этой сцене.")
		return
	get_tree().change_scene_to_file(target_scene)

func InventoryButtonPressed() -> void:
	print("Нажата кнопка: InventoryButton")
	var target_scene = "res://scenes/menu/inventory/Inventory.tscn"
	if get_tree().current_scene.scene_file_path == target_scene:
		print("Вы уже находитесь на этой сцене.")
		return
	get_tree().change_scene_to_file(target_scene)

func ShopButtonPressed() -> void:
	print("Нажата кнопка: ShopButton")
	var target_scene = "res://scenes/menu/shop/Shop.tscn"
	if get_tree().current_scene.scene_file_path == target_scene:
		print("Вы уже находитесь на этой сцене.")
		return
	get_tree().change_scene_to_file(target_scene)
