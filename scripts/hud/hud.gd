extends CanvasLayer
class_name HUD

@export_category("Rectile")
@export var cross_hair_con: Control
@export var second_rectile: SecondaryReticle

@export_category("Bars")
@export var health_bar: ProgressBar
@export var stamina_bar: ProgressBar
@export var level_progress_bar: ProgressBar


@export_category("Enemy")
@export var enemy_compass: Enemy_Compass

@export_category("Containers")
@export var left: VBoxContainer
@export var right: Control

@export_category("Hover Fade")
@export var hover_alpha: float = 0.4
@export var fade_duration: float = 0.15

@export_category("Turret Rotation")
var car: Car_Movement
@export var turret_rotation_marker_container: Control
@export var turret_marker: Control
@export var marker_radius: float = 60.0
@export var marker_screen_offset: Vector2 = Vector2(0, -120)

@export_category("Weapon")
@export var weapon_name: RichTextLabel
@export var ammo_label: RichTextLabel
@export var weapon_slide_distance: float = 40.0
@export var weapon_slide_duration: float = 0.18

var _weapon_swap_tween: Tween

var _left_tween: Tween
var _right_tween: Tween

var magazine_current_ammo: float
var current_weapon_data: WeaponData


func _ready() -> void:
	PauseManager.pause_state_changed.connect(_on_pause_toggle)

	Events.weapon_set.connect(set_weapon)
	Events.magazine_count_changed.connect(change_ammo)

	Events.player_health_changed.connect(update_health)
	Events.player_stamina_changed.connect(update_stamina)
	Events.level_progress_changed.connect(update_progress)
	Events.turret_rotation_changed.connect(_on_turret_rotation_changed)

	left.mouse_entered.connect(_on_left_mouse_entered)
	left.mouse_exited.connect(_on_left_mouse_exited)
	right.mouse_entered.connect(_on_right_mouse_entered)
	right.mouse_exited.connect(_on_right_mouse_exited)


func _process(delta: float) -> void:
	if not is_instance_valid(car):
		return

	var target_screen_pos := car.player_cam.unproject_position(car.global_position)
	var target_pos := target_screen_pos + marker_screen_offset - turret_rotation_marker_container.size / 2.0
	turret_rotation_marker_container.position = turret_rotation_marker_container.position.lerp(target_pos, 20.0 * delta)

#---------------- PAUSE

func _on_pause_toggle():
	visible = !PauseManager.is_paused

#---------------- PROGRESS

func update_progress(current: float, max_distance: float):
	level_progress_bar.value = (current / max_distance) * 100.0

#---------------- ENEMY COMPASS


#---------------- HEALTH

func update_health(value: float):
	health_bar.value = value

#---------------- STAMINA
func update_stamina(value: float):
	stamina_bar.value = value

#---------------- WEAPON

func set_weapon(weapon: WeaponData, direction: int = 1) -> void:
	_swap_weapon_display(weapon, direction)


func _swap_weapon_display(weapon: WeaponData, direction: int) -> void:
	if is_instance_valid(_weapon_swap_tween):
		_weapon_swap_tween.kill()

	var slide := weapon_slide_distance * direction
	var half := weapon_slide_duration * 0.5

	_weapon_swap_tween = create_tween()

	_weapon_swap_tween.set_parallel(true)
	_weapon_swap_tween.tween_property(weapon_name, "position:x", -slide, half)
	_weapon_swap_tween.tween_property(weapon_name, "modulate:a", 0.0, half)

	_weapon_swap_tween.chain().tween_callback(func():
		current_weapon_data = weapon
		weapon_name.text = weapon.name
		update_ammo()
		weapon_name.position.x = slide
	)

	_weapon_swap_tween.chain().set_parallel(true)
	_weapon_swap_tween.tween_property(weapon_name, "position:x", 0.0, half)
	_weapon_swap_tween.tween_property(weapon_name, "modulate:a", 1.0, half)


func change_ammo(count: float):
	magazine_current_ammo = count
	update_ammo()


func update_ammo():
	if current_weapon_data == null:
		return

	var magazine_size := UpgradeManager.get_modified(&"expanded_magazine", current_weapon_data.magazine_capacity)
	ammo_label.text = "%s / %s" % [int(magazine_current_ammo), int(magazine_size)]


func _on_turret_rotation_changed(relative_angle: float) -> void:
	var center := turret_rotation_marker_container.size / 2.0
	var _offset := Vector2(sin(relative_angle), cos(relative_angle)) * marker_radius
	turret_marker.position = center + _offset - turret_marker.size / 2.0
	turret_marker.rotation = -relative_angle

#---------------- HOVER FADE

func _on_left_mouse_entered() -> void:
	_fade(left, hover_alpha, _left_tween)


func _on_left_mouse_exited() -> void:
	_fade(left, 1.0, _left_tween)


func _on_right_mouse_entered() -> void:
	_fade(right, hover_alpha, _right_tween)


func _on_right_mouse_exited() -> void:
	_fade(right, 1.0, _right_tween)


func _fade(control: Control, target_alpha: float, tween: Tween) -> void:
	if is_instance_valid(tween):
		tween.kill()
	tween = create_tween()
	tween.tween_property(control, "modulate:a", target_alpha, fade_duration)
