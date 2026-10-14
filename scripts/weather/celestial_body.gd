extends DirectionalLight3D
class_name CelestialBody

@export var disc: MeshInstance3D

@export_group("Position")
@export var azimuth_deg := 0.0
@export var elevation_deg := 10.0

@export_group("Lighting")
@export var energy := 1.0
@export var min_light_elevation_deg := 6.0
@export var light_fade_start_elevation_deg := -1.0
@export var light_fade_end_elevation_deg := 8.0

@export_group("Disc")
@export var disc_visibility := 1.0
@export var disc_fade_start_elevation_deg := -4.0
@export var disc_fade_end_elevation_deg := 0.0

var energy_boost := 0.0
var direction := Vector3.UP

var _disc_material: ShaderMaterial
var _shadow_wanted := false


func _ready() -> void:
	_shadow_wanted = shadow_enabled
	if disc:
		_disc_material = disc.material_override as ShaderMaterial
		disc.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		disc.extra_cull_margin = 16384.0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func update_body(world_basis: Basis) -> void:
	direction = (world_basis * _local_direction(elevation_deg)).normalized()

	var light_direction := (world_basis * _local_direction(maxf(elevation_deg, min_light_elevation_deg))).normalized()
	global_transform = Transform3D(Basis.looking_at(-light_direction, Vector3.UP), Vector3.ZERO)

	light_energy = energy * light_horizon_factor() + energy_boost
	shadow_enabled = _shadow_wanted and light_energy > 0.001

	if _disc_material:
		_disc_material.set_shader_parameter("body_direction", direction)
		_disc_material.set_shader_parameter("visibility", disc_visibility * disc_horizon_factor())
		disc.visible = disc_visibility > 0.0001


func light_horizon_factor() -> float:
	return smoothstep(light_fade_start_elevation_deg, light_fade_end_elevation_deg, elevation_deg)


func disc_horizon_factor() -> float:
	return smoothstep(disc_fade_start_elevation_deg, disc_fade_end_elevation_deg, elevation_deg)


func set_disc_parameter(parameter: StringName, value: Variant) -> void:
	if _disc_material:
		_disc_material.set_shader_parameter(parameter, value)


func _local_direction(elevation: float) -> Vector3:
	var elevation_basis := Basis(Vector3.RIGHT, deg_to_rad(elevation))
	var azimuth_basis := Basis(Vector3.UP, -deg_to_rad(azimuth_deg))
	return azimuth_basis * elevation_basis * Vector3.FORWARD
