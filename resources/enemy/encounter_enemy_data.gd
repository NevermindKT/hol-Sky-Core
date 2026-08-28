extends Resource
class_name EncounterEnemyData

@export_category("Health")
@export var max_health := 100.0

@export_category("Movement")
@export var move_speed := 5.0
@export var desired_offset := 0.0

@export_category("Attack")
@export var attack_damage := 15.0
@export var attack_delay := 2.0

@export_category("Dash")
@export var dash_speed := 30.0
@export var dash_duration := 1.0

@export_category("Scenes")
@export var enemy_scene: PackedScene
@export var hit_effect_scene: PackedScene
