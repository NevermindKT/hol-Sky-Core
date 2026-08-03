extends Node
class_name Inventory

@export var rifle_ammo: int
@export var pistol_ammo: int
@export var shotgun_ammo: int

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
