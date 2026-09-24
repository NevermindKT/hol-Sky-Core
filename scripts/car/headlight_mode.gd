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

@export_group("Thermal Vision")
@export var thermal_energy_multiplier := 0.15

var is_far_mode := false
var _thermal_active := false


func _ready() -> void:
	InputController.headlights_toggle.connect(_on_toggle)
	Events.thermal_vision_changed.connect(_on_thermal_vision_changed)
	_apply_mode()


func _on_toggle() -> void:
	is_far_mode = !is_far_mode
	_apply_mode()


func _on_thermal_vision_changed(active: bool) -> void:
	_thermal_active = active
	_apply_mode()


func _apply_mode() -> void:
	var energy_multiplier := thermal_energy_multiplier if _thermal_active else 1.0

	if is_far_mode:
		spot_range = far_range
		spot_angle = far_angle
		light_energy = far_energy * energy_multiplier
		spot_attenuation = far_attenuation
		light_volumetric_fog_energy = far_volumetric_fog_energy
	else:
		spot_range = close_range
		spot_angle = close_angle
		light_energy = close_energy * energy_multiplier
		spot_attenuation = close_attenuation
		light_volumetric_fog_energy = close_volumetric_fog_energy
