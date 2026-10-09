extends Node
class_name SkyController

@export var world_environment: WorldEnvironment
@export var sun: CelestialBody
@export var moon: CelestialBody
@export var world: World

@export_group("Dusk")
@export var dusk_duration := 40.0
@export var dusk_sun_azimuth_deg := -20.0
@export var dusk_sun_start_elevation_deg := 7.0
@export var dusk_sun_end_elevation_deg := -8.0
@export var dusk_sky_top_color := Color(0.25, 0.28, 0.33)
@export var dusk_sky_horizon_color := Color(0.85, 0.45, 0.25)
@export var dusk_sky_energy_multiplier := 0.6
@export var dusk_light_color := Color(1.0, 0.7, 0.45)
@export var dusk_light_energy := 0.6

@export var dusk_sun_glow_color := Color(1.0, 0.5, 0.25)
@export var dusk_sun_glow_energy := 1.0

@export_group("Moon")
@export var moon_azimuth_deg := 160.0
@export var moon_rise_start_elevation_deg := -5.0
@export var moon_night_elevation_deg := 25.0
@export var moon_rise_delay := 5.0
@export var moon_rise_duration := 70.0
@export var moon_glow_energy := 0.5

@export_group("Dawn")
@export var dawn_duration := 15.0
@export var dawn_sun_azimuth_deg := 150.0
@export var dawn_start_sun_elevation_deg := -5.0
@export var dawn_end_sun_elevation_deg := 40.0
@export var dawn_sky_horizon_color := Color(1, 1, 1)
@export var dawn_sky_energy_multiplier := 2.5
@export var dawn_light_color := Color(1, 1, 1)
@export var dawn_light_energy := 4.0
@export var dawn_sun_glow_color := Color(1.0, 0.8, 0.6)
@export var dawn_sun_glow_energy := 2.0
@export var dawn_adjustment_brightness := 8.0
@export var dawn_glow_intensity := 2.5

@export_group("Sun glow")
@export var sun_glow_fade_start_elevation_deg := -7.0
@export var sun_glow_fade_end_elevation_deg := 2.0

@export_group("Thermal Vision")
@export var thermal_transition_duration := 0.5
@export var thermal_adjustment_brightness := 3.0
@export var thermal_fog_density := 0.0
@export var thermal_volumetric_fog_density := 0.0


var light_energy_boost := 0.0:
	set(value):
		light_energy_boost = value
		if moon:
			moon.energy_boost = value

var sky_material: ShaderMaterial

var night_sky_top_color: Color
var night_sky_horizon_color: Color
var night_sky_energy_multiplier: float

var night_light_color: Color
var night_light_energy: float
var night_sky_mode: int

var current_sun_elevation_deg: float
var current_light_energy: float
#var light_energy_boost := 0.0
var active_tween: Tween

var night_moon_energy: float

var sun_glow_color := Color(1.0, 0.5, 0.25)
var sun_glow_strength := 0.0
var moon_glow_strength := 0.0

#var active_tween: Tween

var _anchor_basis := Basis.IDENTITY

var _baseline_adjustment_brightness: float
var _baseline_fog_density: float
var _baseline_volumetric_fog_density: float
var _thermal_tween: Tween

var _sky_parameter_cache := {}


func _ready() -> void:
	process_priority = 100

	world_environment.environment = world_environment.environment.duplicate(true)

	var env := world_environment.environment
	env.sky = env.sky.duplicate(true)

	sky_material = env.sky.sky_material as ShaderMaterial
	sky_material = sky_material.duplicate(true)
	env.sky.sky_material = sky_material

	night_sky_top_color = sky_material.get_shader_parameter("sky_top_color")
	night_sky_horizon_color = sky_material.get_shader_parameter("sky_horizon_color")
	night_sky_energy_multiplier = sky_material.get_shader_parameter("sky_energy")
	night_moon_energy = moon.energy

	sun.azimuth_deg = dusk_sun_azimuth_deg
	sun.elevation_deg = dusk_sun_end_elevation_deg
	sun.energy = 0.0
	moon.azimuth_deg = moon_azimuth_deg
	moon.elevation_deg = moon_night_elevation_deg
	moon_glow_strength = moon_glow_energy

	var environment := world_environment.environment
	_baseline_adjustment_brightness = environment.adjustment_brightness
	_baseline_fog_density = environment.fog_density
	_baseline_volumetric_fog_density = environment.volumetric_fog_density

	Events.run_started.connect(play_dusk_intro)
	Events.thermal_vision_changed.connect(_on_thermal_vision_changed)


func _process(_delta: float) -> void:
	var world_basis := Basis.IDENTITY
	if world != null and world.world != null:
		world_basis = world.world.global_transform.basis * _anchor_basis

	sun.update_body(world_basis)
	moon.update_body(world_basis)
	moon.set_disc_parameter("sun_direction", sun.direction)

	var sun_glow_factor := smoothstep(sun_glow_fade_start_elevation_deg, sun_glow_fade_end_elevation_deg, sun.elevation_deg)
	var moon_glow_factor := moon.disc_horizon_factor() * moon.disc_visibility

	_set_sky_direction("sun_direction", sun.direction)
	_set_sky_direction("moon_direction", moon.direction)
	_set_sky_value("sun_glow_color", sun_glow_color)
	_set_sky_value("sun_glow_energy", sun_glow_strength * sun_glow_factor)
	_set_sky_value("moon_glow_energy", moon_glow_strength * moon_glow_factor)


func play_dusk_intro() -> void:
	_kill_active_tween()
	_capture_anchor()

	sun.azimuth_deg = dusk_sun_azimuth_deg
	sun.elevation_deg = dusk_sun_start_elevation_deg
	sun.energy = dusk_light_energy
	sun.light_color = dusk_light_color
	sun.disc_visibility = 1.0
	sun_glow_color = dusk_sun_glow_color
	sun_glow_strength = dusk_sun_glow_energy

	moon.azimuth_deg = moon_azimuth_deg
	moon.elevation_deg = moon_rise_start_elevation_deg
	moon.energy = night_moon_energy
	moon.disc_visibility = 1.0
	moon_glow_strength = moon_glow_energy

	sky_material.set_shader_parameter("sky_top_color", dusk_sky_top_color)
	sky_material.set_shader_parameter("sky_horizon_color", dusk_sky_horizon_color)
	sky_material.set_shader_parameter("sky_energy", dusk_sky_energy_multiplier)

	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE)
	active_tween.set_ease(Tween.EASE_IN_OUT)
	active_tween.set_parallel(true)

	active_tween.tween_property(sun, "elevation_deg", dusk_sun_end_elevation_deg, dusk_duration)
	active_tween.tween_property(sky_material, "shader_parameter/sky_top_color", night_sky_top_color, dusk_duration)
	active_tween.tween_property(sky_material, "shader_parameter/sky_horizon_color", night_sky_horizon_color, dusk_duration)
	active_tween.tween_property(sky_material, "shader_parameter/sky_energy", night_sky_energy_multiplier, dusk_duration)
	active_tween.tween_property(moon, "elevation_deg", moon_night_elevation_deg, moon_rise_duration) \
		.set_delay(moon_rise_delay).set_ease(Tween.EASE_OUT)

	var environment := world_environment.environment
	environment.glow_enabled = false


func play_deadly_dawn() -> void:
	_kill_active_tween()

	var environment := world_environment.environment
	environment.adjustment_enabled = true
	environment.glow_enabled = true

	sun.azimuth_deg = dawn_sun_azimuth_deg
	sun.elevation_deg = dawn_start_sun_elevation_deg
	sun.disc_visibility = 1.0
	sun_glow_color = dawn_sun_glow_color

	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE)
	active_tween.set_ease(Tween.EASE_IN)
	active_tween.set_parallel(true)

	active_tween.tween_property(sun, "elevation_deg", dawn_end_sun_elevation_deg, dawn_duration)
	active_tween.tween_property(sun, "light_color", dawn_light_color, dawn_duration)
	active_tween.tween_property(sun, "energy", dawn_light_energy, dawn_duration)
	active_tween.tween_property(self, "sun_glow_strength", dawn_sun_glow_energy, dawn_duration)
	active_tween.tween_property(moon, "energy", 0.0, dawn_duration * 0.5)
	active_tween.tween_property(moon, "disc_visibility", 0.15, dawn_duration)
	active_tween.tween_property(self, "moon_glow_strength", 0.0, dawn_duration * 0.5)
	active_tween.tween_property(sky_material, "shader_parameter/sky_top_color", dawn_sky_horizon_color, dawn_duration)
	active_tween.tween_property(sky_material, "shader_parameter/sky_horizon_color", dawn_sky_horizon_color, dawn_duration)
	active_tween.tween_property(sky_material, "shader_parameter/sky_energy", dawn_sky_energy_multiplier, dawn_duration)
	active_tween.tween_property(environment, "adjustment_brightness", dawn_adjustment_brightness, dawn_duration)
	active_tween.tween_property(environment, "glow_intensity", dawn_glow_intensity, dawn_duration)


func _capture_anchor() -> void:
	_anchor_basis = Basis.IDENTITY
	if world == null or world.world == null:
		return
	var forward := world.world.global_transform.basis * Vector3.FORWARD
	var yaw := atan2(-forward.x, -forward.z)
	_anchor_basis = Basis(Vector3.UP, -yaw)


func _set_sky_direction(parameter: StringName, value: Vector3) -> void:
	var previous: Variant = _sky_parameter_cache.get(parameter)
	if previous is Vector3 and (previous as Vector3).dot(value) > 0.9999995:
		return
	_sky_parameter_cache[parameter] = value
	sky_material.set_shader_parameter(parameter, value)


func _set_sky_value(parameter: StringName, value: Variant) -> void:
	if _sky_parameter_cache.get(parameter) == value:
		return
	_sky_parameter_cache[parameter] = value
	sky_material.set_shader_parameter(parameter, value)


func _on_thermal_vision_changed(active: bool) -> void:
	var environment := world_environment.environment
	environment.adjustment_enabled = true

	if _thermal_tween and _thermal_tween.is_valid():
		_thermal_tween.kill()

	_thermal_tween = create_tween()
	_thermal_tween.set_parallel(true)

	var target_brightness := thermal_adjustment_brightness if active else _baseline_adjustment_brightness
	var target_fog_density := thermal_fog_density if active else _baseline_fog_density
	var target_volumetric_fog_density := thermal_volumetric_fog_density if active else _baseline_volumetric_fog_density

	_thermal_tween.tween_property(environment, "adjustment_brightness", target_brightness, thermal_transition_duration)
	_thermal_tween.tween_property(environment, "fog_density", target_fog_density, thermal_transition_duration)
	_thermal_tween.tween_property(environment, "volumetric_fog_density", target_volumetric_fog_density, thermal_transition_duration)


func _kill_active_tween() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		play_deadly_dawn()
