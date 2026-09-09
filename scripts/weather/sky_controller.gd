extends Node
class_name SkyController

@export var world_environment: WorldEnvironment
@export var directional_light: DirectionalLight3D
@export var world: World

@export_group("Dusk")
@export var dusk_duration := 20.0
@export var dusk_start_sun_elevation_deg := 5.0
@export var dusk_set_elevation_deg := -15.0
@export var dusk_sky_top_color := Color(0.25, 0.28, 0.33)
@export var dusk_sky_horizon_color := Color(0.85, 0.45, 0.25)
@export var dusk_sky_energy_multiplier := 0.6
@export var dusk_light_color := Color(1.0, 0.7, 0.45)
@export var dusk_light_energy := 0.6

@export_group("Dawn")
@export var dawn_duration := 15.0
@export var dawn_start_sun_elevation_deg := -5.0
@export var dawn_end_sun_elevation_deg := 40.0
@export var dawn_sky_horizon_color := Color(1, 1, 1)
@export var dawn_sky_energy_multiplier := 2.5
@export var dawn_light_color := Color(1, 1, 1)
@export var dawn_light_energy := 4.0
@export var dawn_adjustment_brightness := 8.0
@export var dawn_glow_intensity := 2.5

@export_group("Night baseline")
@export var night_sun_elevation_deg := 25.0

@export_group("Sun disc")
@export var sun_angle_max_deg := 60.0
@export var sun_curve := 0.3

var sky_material: ProceduralSkyMaterial

var night_sky_top_color: Color
var night_sky_horizon_color: Color
var night_sky_energy_multiplier: float
var night_light_color: Color
var night_light_energy: float
var night_sky_mode: int

var current_sun_elevation_deg: float
var current_light_energy: float
var light_energy_boost := 0.0
var active_tween: Tween


func _ready() -> void:
	sky_material = world_environment.environment.sky.sky_material as ProceduralSkyMaterial

	night_sky_top_color = sky_material.sky_top_color
	night_sky_horizon_color = sky_material.sky_horizon_color
	night_sky_energy_multiplier = sky_material.sky_energy_multiplier
	night_light_color = directional_light.light_color
	night_light_energy = directional_light.light_energy
	night_sky_mode = directional_light.sky_mode

	current_sun_elevation_deg = night_sun_elevation_deg
	current_light_energy = night_light_energy

	Events.run_started.connect(play_dusk_intro)


func _process(_delta: float) -> void:
	if world == null or world.world == null:
		return

	var elevation_basis := Basis(Vector3.RIGHT, -deg_to_rad(current_sun_elevation_deg))
	directional_light.global_transform = Transform3D(world.world.global_transform.basis * elevation_basis, Vector3.ZERO)
	directional_light.light_energy = current_light_energy + light_energy_boost


func play_dusk_intro() -> void:
	_kill_active_tween()

	current_sun_elevation_deg = dusk_start_sun_elevation_deg
	current_light_energy = dusk_light_energy
	directional_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sky_material.sun_angle_max = sun_angle_max_deg
	sky_material.sun_curve = sun_curve

	sky_material.sky_top_color = dusk_sky_top_color
	sky_material.sky_horizon_color = dusk_sky_horizon_color
	sky_material.sky_energy_multiplier = dusk_sky_energy_multiplier
	directional_light.light_color = dusk_light_color

	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE)
	active_tween.set_ease(Tween.EASE_IN_OUT)
	active_tween.set_parallel(true)

	active_tween.tween_method(_apply_dusk_elevation, 0.0, 1.0, dusk_duration)
	active_tween.tween_property(sky_material, "sky_top_color", night_sky_top_color, dusk_duration)
	active_tween.tween_property(sky_material, "sky_horizon_color", night_sky_horizon_color, dusk_duration)
	active_tween.tween_property(sky_material, "sky_energy_multiplier", night_sky_energy_multiplier, dusk_duration)
	active_tween.tween_property(directional_light, "light_color", night_light_color, dusk_duration)
	active_tween.tween_property(self, "current_light_energy", night_light_energy, dusk_duration)


func _apply_dusk_elevation(t: float) -> void:
	if t < 0.5:
		current_sun_elevation_deg = lerp(dusk_start_sun_elevation_deg, dusk_set_elevation_deg, t / 0.5)
	else:
		if directional_light.sky_mode != night_sky_mode:
			directional_light.sky_mode = night_sky_mode
		current_sun_elevation_deg = lerp(dusk_set_elevation_deg, night_sun_elevation_deg, (t - 0.5) / 0.5)


func play_deadly_dawn() -> void:
	_kill_active_tween()

	var environment := world_environment.environment
	environment.adjustment_enabled = true
	environment.glow_enabled = true

	current_sun_elevation_deg = dawn_start_sun_elevation_deg
	directional_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sky_material.sun_angle_max = sun_angle_max_deg
	sky_material.sun_curve = sun_curve

	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE)
	active_tween.set_ease(Tween.EASE_IN)
	active_tween.set_parallel(true)

	active_tween.tween_property(self, "current_sun_elevation_deg", dawn_end_sun_elevation_deg, dawn_duration)
	active_tween.tween_property(sky_material, "sky_top_color", dawn_sky_horizon_color, dawn_duration)
	active_tween.tween_property(sky_material, "sky_horizon_color", dawn_sky_horizon_color, dawn_duration)
	active_tween.tween_property(sky_material, "sky_energy_multiplier", dawn_sky_energy_multiplier, dawn_duration)
	active_tween.tween_property(directional_light, "light_color", dawn_light_color, dawn_duration)
	active_tween.tween_property(self, "current_light_energy", dawn_light_energy, dawn_duration)
	active_tween.tween_property(environment, "adjustment_brightness", dawn_adjustment_brightness, dawn_duration)
	active_tween.tween_property(environment, "glow_intensity", dawn_glow_intensity, dawn_duration)


func _kill_active_tween() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		play_deadly_dawn()
