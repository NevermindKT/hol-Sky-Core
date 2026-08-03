extends Resource
class_name WeaponData

@export var name: String

@export_category("General")
@export var damage: float
@export var fire_rate: float
@export var reload_speed: float
@export var magazine_capacity: float
@export var ammo_type: Ammo_Type.Type

@export_category("Projectile gravity")
@export var gravity_scale: float
@export var projectile_speed: float
@export var projectile_distance: float

@export_category("Spread")
@export var spread_angle: float
@export var projectile_count: float

@export_category("Exports")
@export var fire_behavior: Fire_behavior
@export var projectile_scene: PackedScene
