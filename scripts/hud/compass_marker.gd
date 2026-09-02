extends TextureRect
class_name Enemy_Marker

@export var blink_interval: float = 0.15

var enemy: Encounter_Enemy
@onready var marker_warning: TextureRect = $MarkerWarning

var is_warning_active := false
var blink_timer := 0.0


func set_enemy(target_enemy: Encounter_Enemy) -> void:
	enemy = target_enemy
	enemy.attack_state_changed.connect(_on_attack_state_changed)
	enemy.tree_exiting.connect(_on_enemy_removed)
	marker_warning.visible = false


func _process(delta: float) -> void:
	if not is_warning_active:
		return
	
	blink_timer -= delta
	if blink_timer <= 0.0:
		blink_timer = blink_interval
		marker_warning.visible = not marker_warning.visible


func _on_attack_state_changed(is_warning: bool) -> void:
	is_warning_active = is_warning
	blink_timer = 0.0
	marker_warning.visible = is_warning


func _on_enemy_removed() -> void:
	is_warning_active = false
	marker_warning.visible = false
