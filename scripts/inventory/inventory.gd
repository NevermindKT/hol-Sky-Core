extends Node
class_name PlayerInventory

@export var rifle_ammo: int
@export var pistol_ammo: int
@export var shotgun_ammo: int

@export_category("Inventory Link")
@export var pistol_ammo_id: String
@export var rifle_ammo_id: String
@export var shotgun_ammo_id: String


func _ready() -> void:
	load_from_base_inventory()


func load_from_base_inventory() -> void:
	if not pistol_ammo_id.is_empty():
		pistol_ammo = _get_stored_quantity(pistol_ammo_id)
	if not rifle_ammo_id.is_empty():
		rifle_ammo = _get_stored_quantity(rifle_ammo_id)
	if not shotgun_ammo_id.is_empty():
		shotgun_ammo = _get_stored_quantity(shotgun_ammo_id)


func _get_stored_quantity(object_id: String) -> int:
	var row: Dictionary = BaseInventoryManager.find_object_by_id(object_id)
	return maxi(int(row.get("Quantity", 0)), 0)


func consume_ammo(ammo_type: Ammo_Type.Type, amount: int) -> int:
	match ammo_type:
		Ammo_Type.Type.PISTOL:
			var taken = min(pistol_ammo, amount)
			pistol_ammo -= taken
			return taken

		Ammo_Type.Type.RIFLE:
			var taken = min(rifle_ammo, amount)
			rifle_ammo -= taken
			return taken

		Ammo_Type.Type.SHOTGUN:
			var taken = min(shotgun_ammo, amount)
			shotgun_ammo -= taken
			return taken
	return 0


func get_ammo(ammo_type: Ammo_Type.Type) -> int:
	match ammo_type:
		Ammo_Type.Type.PISTOL:
			return pistol_ammo

		Ammo_Type.Type.RIFLE:
			return rifle_ammo

		Ammo_Type.Type.SHOTGUN:
			return shotgun_ammo
	return 0

func commit_to_base_inventory() -> void:
	_set_stored_quantity(pistol_ammo_id, pistol_ammo)
	_set_stored_quantity(rifle_ammo_id, rifle_ammo)
	_set_stored_quantity(shotgun_ammo_id, shotgun_ammo)
	BaseInventoryManager.save_data()
	BaseInventoryManager.inventory_changed.emit()


func _set_stored_quantity(object_id: String, amount: int) -> void:
	if object_id.is_empty():
		return
	var row: Dictionary = BaseInventoryManager.find_object_by_id(object_id)
	if not row.is_empty():
		row["Quantity"] = maxi(amount, 0)
