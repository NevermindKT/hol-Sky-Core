extends SpotLight3D
class_name Headlight_Mode

@export_group("Low Beam")
@export var close_range: float = 45.0
@export var close_angle: float = 22.0
@export var close_energy: float = 10.0
@export var close_attenuation: float = 0.3
@export var close_volumetric_fog_energy: float = 2.0

@export_group("High Beam")
@export var far_range: float = 130.0
@export var far_angle: float = 9.0
@export var far_energy: float = 16.0
@export var far_attenuation: float = 0.05
@export var far_volumetric_fog_energy: float = 4.0

var is_far_mode := false


func _ready() -> void:
	InputController.headlights_toggle.connect(_on_toggle)
	_apply_mode()


func _on_toggle() -> void:
	is_far_mode = !is_far_mode
	_apply_mode()


func _apply_mode() -> void:
	if is_far_mode:
		spot_range = far_range
		spot_angle = far_angle
		light_energy = far_energy
		spot_attenuation = far_attenuation
		light_volumetric_fog_energy = far_volumetric_fog_energy
	else:
		spot_range = close_range
		spot_angle = close_angle
		light_energy = close_energy
		spot_attenuation = close_attenuation
		light_volumetric_fog_energy = close_volumetric_fog_energy
