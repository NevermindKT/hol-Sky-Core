extends Node3D
class_name Detached_Wheel

@export var body: RigidBody3D
@export var pose: Node3D
@export var spin: Node3D
@export var ground_body: StaticBody3D
@export var ground_shape: CollisionShape3D

@export_category("Launch")
@export_range(0.5, 1.5, 0.01) var inherit_speed := 1.08
@export var launch_up_speed := 2.0
@export var launch_side_speed := 1.5
@export var wheel_radius := 0.31

@export_category("Rolling")
@export var upright_strength := 30.0
@export var upright_damping := 6.0
@export var side_grip := 4.0
@export var lean_deg := 7.0
@export var lean_wobble_deg := 4.0
@export var lean_wobble_frequency := 2.5
@export var drift_turn_rate_deg := 5.0
@export var upright_min_speed := 5.0
@export var upright_time := 8.0
@export var ground_contact_margin := 0.2
@export var rolling_decel := 2.5
@export var rolling_friction := 0.05
@export var fallen_friction := 0.8

@export_category("Ground")
@export_range(4, 64, 2) var ground_patch_cells := 24
@export var ground_recenter_distance := 6.0

@export_category("Lifetime")
@export var despawn_distance := 200.0
@export var max_lifetime := 30.0
@export var fall_limit := 30.0

var world: World
var car: Car_Movement

var _last_world := Transform3D.IDENTITY
var _prev_local := Transform3D.IDENTITY
var _curr_local := Transform3D.IDENTITY
var _heading := Vector3.FORWARD
var _side := 1.0
var _age := 0.0
var _upright := true
var _spin_angle := 0.0
var _rolling_speed := 0.0
var _ground_center := Vector2(INF, INF)
var _fallback_height := 0.0
var _heights := PackedFloat32Array()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if body.physics_material_override:
		body.physics_material_override = body.physics_material_override.duplicate()
		body.physics_material_override.friction = rolling_friction


func launch(source_world: World, source_car: Car_Movement, from: Transform3D, side: float) -> void:
	world = source_world
	car = source_car
	_side = side if side != 0.0 else 1.0

	_last_world = world.world.global_transform
	var local := _last_world.affine_inverse() * from.orthonormalized()
	var ground := _ground_height(local.origin.x, local.origin.z)
	if is_finite(ground):
		local.origin.y = maxf(local.origin.y, ground + wheel_radius)
		_fallback_height = ground
	else:
		_fallback_height = local.origin.y - wheel_radius

	var forward := _car_forward()
	_heading = (_last_world.basis.inverse() * forward)
	_heading.y = 0.0
	_heading = _heading.normalized() if _heading.length_squared() > 0.0001 else Vector3.FORWARD

	_prev_local = local
	_curr_local = local
	pose.transform = local
	_update_ground(local.origin)

	var speed := _car_speed() * inherit_speed
	var right := car.global_transform.basis.x if car else Vector3.RIGHT

	body.top_level = true
	body.global_transform = _last_world * local
	body.linear_velocity = forward * speed + Vector3.UP * launch_up_speed + right * _side * launch_side_speed
	body.angular_velocity = Vector3.ZERO
	_rolling_speed = speed


func _physics_process(delta: float) -> void:
	if world == null:
		return

	_age += delta

	var current_world := world.world.global_transform
	var local := _last_world.affine_inverse() * body.global_transform
	_prev_local = _curr_local
	_curr_local = local

	var shift := current_world * _last_world.affine_inverse()
	var linear := body.linear_velocity
	var angular := body.angular_velocity
	body.global_transform = current_world * local
	body.linear_velocity = shift.basis * linear
	body.angular_velocity = shift.basis * angular
	_last_world = current_world

	_update_ground(local.origin)
	_process_rolling(delta, local)

	if _should_despawn(local.origin):
		queue_free()

# ============================ ROLLING =========================================

func _process_rolling(delta: float, local: Transform3D) -> void:
	if not _upright:
		return

	if _age > upright_time or body.linear_velocity.length() < upright_min_speed:
		_release()
		return

	_heading = _heading.rotated(Vector3.UP, -_side * deg_to_rad(drift_turn_rate_deg) * delta)

	var world_basis := world.world.global_transform.basis.orthonormalized()
	var heading := world_basis * _heading
	var up := world_basis * Vector3.UP
	var right := heading.cross(up).normalized()

	var lean := deg_to_rad(lean_deg) + sin(_age * lean_wobble_frequency * TAU) * deg_to_rad(lean_wobble_deg)
	var target_up := (up + right * _side * tan(lean)).normalized()
	var target_axle := heading.cross(target_up).normalized()

	var axle := body.global_transform.basis.x.normalized()
	var angular := body.angular_velocity
	var spin := axle * axle.dot(angular)
	var wobble := angular - spin

	body.angular_velocity = wobble + (axle.cross(target_axle) * upright_strength - wobble * upright_damping) * delta

	var rolling_direction := up.cross(axle).normalized()
	_rolling_speed = body.linear_velocity.dot(rolling_direction)

	if _is_grounded(local.origin):
		var linear := body.linear_velocity
		var flat_axle := axle - up * axle.dot(up)
		if flat_axle.length_squared() > 0.0001:
			flat_axle = flat_axle.normalized()
			linear -= flat_axle * flat_axle.dot(linear) * clampf(side_grip * delta, 0.0, 1.0)

		var ground_speed := linear - up * linear.dot(up)
		if ground_speed.length_squared() > 0.0001:
			linear -= ground_speed.normalized() * minf(rolling_decel * delta, ground_speed.length())

		body.linear_velocity = linear


func _release() -> void:
	_upright = false

	if body.physics_material_override:
		body.physics_material_override.friction = fallen_friction

	var axle := body.global_transform.basis.x.normalized()
	body.angular_velocity += axle * (-_rolling_speed / wheel_radius)


func _is_grounded(local_position: Vector3) -> bool:
	var ground := _ground_height(local_position.x, local_position.z)
	if not is_finite(ground):
		return true
	return local_position.y - ground < wheel_radius + ground_contact_margin


func _process(delta: float) -> void:
	if world == null:
		return
	pose.transform = _prev_local.interpolate_with(_curr_local, Engine.get_physics_interpolation_fraction())

	if _upright and spin:
		_spin_angle = wrapf(_spin_angle - _rolling_speed / wheel_radius * delta, 0.0, TAU)
		spin.rotation.x = _spin_angle

# ============================ GROUND ==========================================

func _update_ground(local_position: Vector3) -> void:
	var center := Vector2(local_position.x, local_position.z)
	if _ground_center.distance_to(center) < ground_recenter_distance:
		return

	_ground_center = center.round()

	var size := ground_patch_cells + 1
	var half := ground_patch_cells / 2
	_heights.resize(size * size)

	for iz in size:
		for ix in size:
			var h := _ground_height(_ground_center.x + ix - half, _ground_center.y + iz - half)
			_heights[iz * size + ix] = h if is_finite(h) else _fallback_height

	var shape := ground_shape.shape as HeightMapShape3D
	shape.map_width = size
	shape.map_depth = size
	shape.map_data = _heights
	ground_body.position = Vector3(_ground_center.x, 0.0, _ground_center.y)


func _ground_height(x: float, z: float) -> float:
	if world == null or world.ground == null:
		return INF
	return world.ground.ground_height(x, z)

# ============================ HELPERS =========================================

func _should_despawn(local_position: Vector3) -> bool:
	if _age > max_lifetime:
		return true
	if local_position.y < _fallback_height - fall_limit:
		return true
	if car and body.global_position.distance_to(car.global_position) > despawn_distance:
		return true
	return false


func _car_forward() -> Vector3:
	if car == null:
		return Vector3.FORWARD
	var forward := -car.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


func _car_speed() -> float:
	return car.speed if car else 0.0
