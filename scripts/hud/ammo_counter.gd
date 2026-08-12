extends VBoxContainer
class_name Ammo_counter

@onready var ammo_label: RichTextLabel = $AmmoLabel
@onready var weapon_name: RichTextLabel = $WeaponName

var magazine_size: float
var magazine_current_ammo: float


func _ready() -> void:
	Events.weapon_set.connect(set_weapon)
	Events.magazine_count_changed.connect(change_ammo)
	update_ammo()


func set_weapon(weapon: WeaponData):
	magazine_size = weapon.magazine_capacity
	weapon_name.text = weapon.name
	update_ammo()


func change_ammo(count: float):
	magazine_current_ammo = count
	update_ammo()


func update_ammo():
	ammo_label.text = "%s / %s" % [magazine_current_ammo, magazine_size]
