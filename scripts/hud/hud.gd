extends CanvasLayer
class_name HUD

@onready var cross_hair_con: Control = $CrossHairCon

@onready var health_bar: ProgressBar = $Left/HealthBar
@onready var level_progress_bar: ProgressBar = $Top/LevelProgressBar

@onready var ammo_label: RichTextLabel = $Right/AmmoLabel
@onready var weapon_name: RichTextLabel = $Right/WeaponName

var magazine_size: float
var magazine_current_ammo: float


func _ready() -> void:
	PauseManager.pause_state_changed.connect(_on_pause_toggle)
	
	Events.weapon_set.connect(set_weapon)
	Events.magazine_count_changed.connect(change_ammo)
	
	Events.player_health_changed.connect(update_health)
	Events.level_progress_changed.connect(update_progress)


#---------------- PAUSE

func _on_pause_toggle():
	visible = !PauseManager.is_paused

#---------------- PROGRESS

func update_progress(current: float, max_distance: float):
	level_progress_bar.value = (current / max_distance) * 100.0

#---------------- HEALTH

func update_health(value: float):
	health_bar.value = value

#---------------- WEAPON

func set_weapon(weapon: WeaponData):
	magazine_size = weapon.magazine_capacity
	weapon_name.text = weapon.name
	update_ammo()


func change_ammo(count: float):
	magazine_current_ammo = count
	update_ammo()


func update_ammo():
	ammo_label.text = "%s / %s" % [int(magazine_current_ammo), int(magazine_size)]
