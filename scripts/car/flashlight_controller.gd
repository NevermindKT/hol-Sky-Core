extends SpotLight3D
class_name Flashlight_Mode

@export_group("Close Mode")
@export var close_range: float = 25.0
@export var close_angle: float = 25.0
@export var close_energy: float = 5.0
@export var close_volumetric_fog_energy: float = 1.0

@export_group("Far Mode")
@export var far_range: float = 60.0
@export var far_angle: float = 6.0
@export var far_energy: float = 12.0
@export var far_volumetric_fog_energy: float = 3.0

@export_group("Thermal Vision")
@export var thermal_energy_multiplier := 0.15

var is_far_mode := false
var _thermal_active := false


func _ready() -> void:
	InputController.flashlight_toggle.connect(_on_toggle)
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
		light_volumetric_fog_energy = far_volumetric_fog_energy
	else:
		spot_range = close_range
		spot_angle = close_angle
		light_energy = close_energy * energy_multiplier
		light_volumetric_fog_energy = close_volumetric_fog_energy
