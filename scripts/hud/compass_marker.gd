extends TextureProgressBar
class_name Enemy_Marker

@export var blink_interval: float = 0.15
@onready var marker_warning: TextureRect = $MarkerWarning
@onready var stun_progress_bar: TextureProgressBar = $StunProgressBar

var enemy: Encounter_Enemy


var blink_timer := 0.0
var is_warning_active := false

func set_enemy(target_enemy: Encounter_Enemy) -> void:
	enemy = target_enemy
	enemy.attack_state_changed.connect(_on_attack_state_changed)
	enemy.health_changed.connect(_on_health_changed)
	enemy.tree_exiting.connect(_on_enemy_removed)
	marker_warning.visible = false

	max_value = enemy.enemy_data.max_health
	value = enemy.health
	stun_progress_bar.max_value = enemy.enemy_data.stun_treshold
	stun_progress_bar.value = 0.0


func _process(delta: float) -> void:
	_update_stun_bar()
	_update_warning_blink(delta)


func _update_stun_bar() -> void:
	if not is_instance_valid(enemy):
		return
	stun_progress_bar.value = enemy.stun_meter


func _update_warning_blink(delta: float) -> void:
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


func _on_health_changed(current: float, maximum: float) -> void:
	max_value = maximum
	create_tween().tween_property(self, "value", current, 0.15)
