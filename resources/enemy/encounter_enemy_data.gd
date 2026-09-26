extends Resource
class_name EncounterEnemyData

@export_category("Group")
@export var weight := 25.0

@export_category("Health")
@export var max_health := 100.0

@export_category("Movement")
@export var move_speed := 5.0
@export var desired_offset := 0.0
@export var z_return_speed := 6.0
@export var z_align_speed := 10.0 

@export_category("Inertia")
@export var inertia_resistance := 1.0

@export_category("Catch Up")
@export var catch_up_distance := 8.0
@export var catch_up_multiplier := 2.0

@export_category("Attack")
@export var attack_damage := 15.0
@export var attack_range_x := 3.0
@export var attack_delay := 2.0
@export var attack_speed_loss := 8.0
@export var attack_warning_time := 0.5

@export_category("Stun")
@export var stun_duration := 5.0
@export var stun_treshold := 100.0
@export var stun_decay_rate := 20.0
@export var stun_decay_delay := 1.0

@export_category("Dash")
@export var dash_speed := 30.0
@export var dash_duration := 1.0

@export_category("Scenes")
@export var enemy_scene: PackedScene
@export var dodge_hit_effect_scene: PackedScene
@export var bullet_hit_effect_scene: PackedScene
