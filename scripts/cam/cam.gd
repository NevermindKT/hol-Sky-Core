extends Camera3D
class_name Player_Camera

@export var car: Car_Movement

@export_group("Lateral Follow")
@export var lateral_spring := 22.0
@export var lateral_damping := 14.0
@export var yaw_gain_deg := 0.6
@export var yaw_max_deg := 2.5
@export var yaw_smoothing := 3.5
@export var roll_gain_deg := 0.1
@export var roll_max_deg := 2.0
@export var roll_smoothing := 3.5

@export_group("Speed Orbit")
@export var speed_feel_smoothing := 2.0
@export var fov_min := 75.0
@export var fov_max := 100.0
@export var fov_smoothing := 8.0
@export var distance_min := 5.0
@export var distance_max := 9.0
@export var height_min := 4.0
@export var height_max := 7.0

@export_group("Input Push")
@export var accel_distance_push := 1.5
@export var accel_fov_push := 6.0
@export var brake_distance_push := 1.2
@export var brake_fov_push := 5.0
@export var push_smoothing := 5.0

@export_group("Impact Shake")
@export var impact_spring := 60.0
@export var impact_damping := 10.0
@export var impact_rot_spring := 50.0
@export var impact_rot_damping := 9.0
@export var impact_noise_duration := 0.25
@export var incoming_lateral_impulse_per_damage := 0.05
@export var incoming_vertical_impulse_per_damage := 0.04
@export var incoming_roll_impulse_per_damage_deg := 1.2
@export var incoming_pitch_impulse_per_damage_deg := 1.0
@export var incoming_noise_per_damage := 0.03
@export var outgoing_lateral_impulse_per_damage := 0.04
@export var outgoing_roll_impulse_per_damage_deg := 1.0
@export var outgoing_noise_per_damage := 0.02

@export_group("Aim")
@export_range(0.0, 1.0) var aim_shake_influence := 0.15

@export_group("Aim Lean")
@export var aim_lean_smoothing := 4.0
@export var aim_lean_horizontal := 0.5
@export var aim_lean_vertical := 0.3
@export var aim_lean_yaw_deg := 3.0
@export var aim_lean_pitch_deg := 2.0

# Layer 1: lateral spring follow + yaw/roll
var _cam_x := 0.0
var _lateral_vel := 0.0
var _yaw := 0.0
var _roll := 0.0

# Layer 1: speed-driven distance/height/fov base
var _speed_feel := 0.0
var _distance_base := 0.0
var _height_base := 0.0

# Layer 2: W/S push on top of the base
var _accel_push := 0.0
var _brake_push := 0.0
var _distance_push := 0.0
var _fov_push := 0.0

# Layer 3: impact impulses (spring-damped) + short noise shake
var _impact_pos_offset := Vector3.ZERO
var _impact_pos_vel := Vector3.ZERO
var _impact_rot_offset := Vector3.ZERO
var _impact_rot_vel := Vector3.ZERO
var _noise_magnitude := 0.0
var _noise_time_left := 0.0
var _noise_offset := Vector3.ZERO

# Layer 4: transform used for the aim ray, blended between stable (layer 1) and full (1+2+3)
var _aim_transform := Transform3D()

# Cosmetic render-only lean towards where the reticle points on screen
var _aim_lean := Vector2.ZERO


func _ready() -> void:
	_cam_x = global_position.x
	Events.player_take_damage.connect(_on_player_take_damage)


func _physics_process(delta: float) -> void:
	_process_lateral_follow(delta)
	_process_speed_feel(delta)
	_process_input_push(delta)
	_process_impact(delta)
	_process_aim_lean(delta)

	var forward := -car.global_transform.basis.z
	var stable_transform := _build_base_transform(forward, _distance_base, _height_base)
	var full_transform := _build_base_transform(forward, _distance_base + _distance_push, _height_base)

	full_transform.origin += Vector3(_impact_pos_offset.x, _impact_pos_offset.y, 0.0) + _noise_offset
	full_transform = full_transform.rotated_local(Vector3.FORWARD, _impact_rot_offset.z)
	full_transform = full_transform.rotated_local(Vector3.RIGHT, _impact_rot_offset.x)

	_aim_transform = stable_transform.interpolate_with(full_transform, aim_shake_influence)

	var render_transform := full_transform
	render_transform.origin += (
		full_transform.basis.x * (_aim_lean.x * aim_lean_horizontal)
		+ full_transform.basis.y * (-_aim_lean.y * aim_lean_vertical)
	)
	render_transform = render_transform.rotated_local(Vector3.UP, -_aim_lean.x * deg_to_rad(aim_lean_yaw_deg))
	render_transform = render_transform.rotated_local(Vector3.RIGHT, -_aim_lean.y * deg_to_rad(aim_lean_pitch_deg))
	global_transform = render_transform

	var mod_fov_min := UpgradeManager.get_modified(&"camera_fov", fov_min)
	var mod_fov_max := UpgradeManager.get_modified(&"camera_fov", fov_max)
	var target_fov: float = lerp(mod_fov_min, mod_fov_max, _speed_feel) + _fov_push
	fov = lerpf(fov, target_fov, 1.0 - exp(-fov_smoothing * delta))

# ============================ LAYER 1: BASE FOLLOW ============================

func _process_lateral_follow(delta: float) -> void:
	var target_x := car.cam_pivot.global_position.x
	var error := target_x - _cam_x

	_lateral_vel += error * lateral_spring * delta
	_lateral_vel *= exp(-lateral_damping * delta)
	_cam_x += _lateral_vel * delta

	var yaw_target := clampf(-error * deg_to_rad(yaw_gain_deg), -deg_to_rad(yaw_max_deg), deg_to_rad(yaw_max_deg))
	_yaw = lerp_angle(_yaw, yaw_target, 1.0 - exp(-yaw_smoothing * delta))

	var roll_target := clampf(-car.lateral_velocity * deg_to_rad(roll_gain_deg), -deg_to_rad(roll_max_deg), deg_to_rad(roll_max_deg))
	_roll = lerp_angle(_roll, roll_target, 1.0 - exp(-roll_smoothing * delta))


func _process_speed_feel(delta: float) -> void:
	_speed_feel = lerp(_speed_feel, car.get_speed_ratio(), 1.0 - exp(-speed_feel_smoothing * delta))
	_distance_base = lerp(distance_min, distance_max, _speed_feel)
	_height_base = lerp(height_min, height_max, _speed_feel)


func _build_base_transform(forward: Vector3, distance: float, height: float) -> Transform3D:
	var pivot := car.cam_pivot.global_position
	var pos := pivot - forward * distance + Vector3.UP * height
	pos.x = _cam_x

	# Дивимось на точку з X камери (а не реального pivot), щоб відставання по X
	# саме по собі не створювало прихований, непідконтрольний Inspector-параметрам
	# розворот — єдине джерело yaw має бути явне, нижче.
	var look_target := Vector3(pos.x, pivot.y, pivot.z)
	var t := Transform3D(Basis(), pos).looking_at(look_target, Vector3.UP)
	t = t.rotated_local(Vector3.UP, _yaw)
	t = t.rotated_local(Vector3.FORWARD, _roll)
	return t

func _process_aim_lean(delta: float) -> void:
	var viewport := get_viewport()
	var vp_size := viewport.get_visible_rect().size
	var screen_offset := Vector2.ZERO
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		var mouse_pos := viewport.get_mouse_position()
		screen_offset = (mouse_pos - vp_size * 0.5) / (vp_size * 0.5)
	screen_offset = screen_offset.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))

	_aim_lean = _aim_lean.lerp(screen_offset, 1.0 - exp(-aim_lean_smoothing * delta))

# ============================ LAYER 2: INPUT PUSH ==============================

func _process_input_push(delta: float) -> void:
	var t := 1.0 - exp(-push_smoothing * delta)
	_accel_push = lerp(_accel_push, 1.0 if InputController.accelerating else 0.0, t)
	_brake_push = lerp(_brake_push, 1.0 if InputController.braking else 0.0, t)

	_distance_push = _accel_push * accel_distance_push - _brake_push * brake_distance_push
	_fov_push = _accel_push * accel_fov_push - _brake_push * brake_fov_push

# ============================ LAYER 3: IMPACT IMPULSES =========================

func _process_impact(delta: float) -> void:
	_impact_pos_vel += -_impact_pos_offset * impact_spring * delta
	_impact_pos_vel *= exp(-impact_damping * delta)
	_impact_pos_offset += _impact_pos_vel * delta

	_impact_rot_vel += -_impact_rot_offset * impact_rot_spring * delta
	_impact_rot_vel *= exp(-impact_rot_damping * delta)
	_impact_rot_offset += _impact_rot_vel * delta

	if _noise_time_left > 0.0:
		_noise_time_left -= delta
		var noise_t := clampf(_noise_time_left / impact_noise_duration, 0.0, 1.0)
		var magnitude := _noise_magnitude * noise_t
		_noise_offset = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * magnitude
	else:
		_noise_offset = Vector3.ZERO
		_noise_magnitude = 0.0


func _apply_impulse(pos_impulse: Vector3, rot_impulse: Vector3, noise_amount: float) -> void:
	_impact_pos_vel += pos_impulse
	_impact_rot_vel += rot_impulse
	_noise_magnitude = maxf(_noise_magnitude, noise_amount)
	_noise_time_left = impact_noise_duration


func apply_incoming_hit(source_position: Vector3, damage: float) -> void:
	var right := car.global_transform.basis.x
	var forward := -car.global_transform.basis.z

	var dir := source_position - car.global_position
	dir = dir.normalized() if dir.length() > 0.001 else -forward

	var lateral := dir.dot(right)
	var longitudinal := dir.dot(forward)

	var pos_impulse := Vector3(
		-lateral * incoming_lateral_impulse_per_damage * damage,
		-longitudinal * incoming_vertical_impulse_per_damage * damage,
		0.0
	)
	var rot_impulse := Vector3(
		-longitudinal * deg_to_rad(incoming_pitch_impulse_per_damage_deg) * damage,
		0.0,
		-lateral * deg_to_rad(incoming_roll_impulse_per_damage_deg) * damage
	)
	_apply_impulse(pos_impulse, rot_impulse, incoming_noise_per_damage * damage)


func apply_outgoing_hit(contact_point: Vector3, damage: float) -> void:
	var right := car.global_transform.basis.x

	var dir := contact_point - car.global_position
	dir = dir.normalized() if dir.length() > 0.001 else right

	var lateral := dir.dot(right)

	var pos_impulse := Vector3(-lateral * outgoing_lateral_impulse_per_damage * damage, 0.0, 0.0)
	var rot_impulse := Vector3(0.0, 0.0, -lateral * deg_to_rad(outgoing_roll_impulse_per_damage_deg) * damage)
	_apply_impulse(pos_impulse, rot_impulse, outgoing_noise_per_damage * damage)


func _on_player_take_damage(damage: float, source_position: Vector3) -> void:
	apply_incoming_hit(source_position, damage)

# ============================ LAYER 4: AIM BLEND ===============================

func get_aim_transform() -> Transform3D:
	return _aim_transform
