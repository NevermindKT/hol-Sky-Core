extends Node3D
class_name Enemy_Corpse

@export var body: RigidBody3D
@export var pose: Node3D
@export var visual: MeshInstance3D
@export var car_hit_area: Area3D
@export var ground_body: StaticBody3D
@export var ground_shape: CollisionShape3D

@export_category("Launch")
@export_range(0.0, 1.5, 0.01) var inherit_speed := 0.85
@export var launch_up_speed := 2.0
@export var launch_spin := 3.0
@export var spawn_center_height := 1.05

@export_category("Car Hit")
@export var car_hit_min_speed := 20.0
@export var car_hit_damage := 10.0
@export var car_hit_speed_loss := 15.0
@export var car_hit_effect_scale := 1.5
@export var car_hit_arm_time := 0.3
@export_range(0.0, 2.0, 0.01) var car_hit_launch_ratio := 1.15
@export var car_hit_launch_up := 5.0
@export var car_hit_launch_side := 3.0
@export var car_hit_spin := 10.0

@export_category("Ground")
@export_range(4, 64, 2) var ground_patch_cells := 24
@export var ground_recenter_distance := 6.0

@export_category("Lifetime")
@export var despawn_distance := 90.0
@export var max_lifetime := 40.0
@export var fall_limit := 30.0

var world: World
var car: Car_Movement
var thermal_material: Material

var _last_world := Transform3D.IDENTITY
var _prev_local := Transform3D.IDENTITY
var _curr_local := Transform3D.IDENTITY
var _age := 0.0
var _damage_dealt := false
var _ground_center := Vector2(INF, INF)
var _fallback_height := 0.0
var _heights := PackedFloat32Array()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	car_hit_area.body_entered.connect(_on_car_hit_area_body_entered)
	Events.thermal_vision_changed.connect(_on_thermal_vision_changed)


func launch(source_world: World, source_car: Car_Movement, from: Transform3D, mesh: Mesh, thermal: Material, push: Vector3) -> void:
	world = source_world
	car = source_car
	thermal_material = thermal
	if mesh:
		visual.mesh = mesh
	_on_thermal_vision_changed(Events.thermal_vision_active)

	_last_world = world.world.global_transform
	var local := _last_world.affine_inverse() * from
	var ground := _ground_height(local.origin.x, local.origin.z)
	if is_finite(ground):
		local.origin.y = maxf(local.origin.y, ground + spawn_center_height)
		_fallback_height = ground
	else:
		_fallback_height = local.origin.y - spawn_center_height

	_prev_local = local
	_curr_local = local
	pose.transform = local
	_update_ground(local.origin)

	body.top_level = true
	body.global_transform = _last_world * local
	body.linear_velocity = _car_forward() * _car_speed() * inherit_speed + push + Vector3.UP * launch_up_speed
	body.angular_velocity = _random_vector() * launch_spin


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

	if _should_despawn(local.origin):
		queue_free()


func _process(_delta: float) -> void:
	if world == null:
		return
	pose.transform = _prev_local.interpolate_with(_curr_local, Engine.get_physics_interpolation_fraction())

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

# ============================ CAR HIT =========================================

func _on_car_hit_area_body_entered(other: Node3D) -> void:
	var hit_car := other as Car_Movement
	if hit_car == null:
		return
	if _age < car_hit_arm_time:
		return
	if hit_car.speed < car_hit_min_speed:
		return

	var hit_position := body.global_position

	if not _damage_dealt:
		_damage_dealt = true
		Events.player_take_damage.emit(car_hit_damage, hit_position)
		hit_car.spawn_hit_effect(hit_position, car_hit_effect_scale)
		hit_car.apply_impact_speed_loss(car_hit_speed_loss)

	var side := signf(hit_position.x - hit_car.global_position.x)
	if side == 0.0:
		side = 1.0 if randf() < 0.5 else -1.0

	body.linear_velocity = _car_forward() * hit_car.speed * car_hit_launch_ratio \
		+ Vector3.UP * car_hit_launch_up \
		+ hit_car.global_transform.basis.x * side * car_hit_launch_side
	body.angular_velocity = _random_vector() * car_hit_spin

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


func _random_vector() -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))


func _on_thermal_vision_changed(active: bool) -> void:
	visual.material_override = thermal_material if active else null
