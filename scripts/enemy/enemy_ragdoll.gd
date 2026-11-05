extends Node3D
class_name Enemy_Ragdoll

const BONE_LAYER := 16
const BONE_MASK := 4 | 32
const GROUND_LAYER := 32

@export_category("Launch")
@export_range(0.0, 1.5, 0.01) var inherit_speed := 0.4
@export var launch_up_speed := 1.5
@export var launch_spin := 2.0

@export_category("Body")
@export var total_mass := 35.0
@export var linear_damp := 0.2
@export var angular_damp := 1.5
@export var friction := 0.9
@export var bounce := 0.1
@export var twist_span := 20.0

@export_category("Car Hit")
@export var car_hit_radius := 1.0
@export var car_hit_min_speed := 20.0
@export var car_hit_damage := 10.0
@export var car_hit_speed_loss := 15.0
@export var car_hit_effect_scale := 1.5
@export var car_hit_arm_time := 0.3
@export_range(0.0, 2.0, 0.01) var car_hit_launch_ratio := 0.7
@export var car_hit_launch_up := 5.0
@export var car_hit_launch_side := 6.0
@export var car_hit_cooldown := 0.6
@export var car_hit_spin := 10.0

@export_category("Ground")
@export_range(4, 64, 2) var ground_patch_cells := 24
@export var ground_recenter_distance := 6.0

@export_category("Lifetime")
@export var despawn_distance := 90.0
@export var despawn_behind := 30.0
@export var max_lifetime := 30.0
@export var fall_limit := 30.0

var world: World
var car: Car_Movement
var target: Node3D
var bones: Array[PhysicalBone3D] = []
var root_bone: PhysicalBone3D

var _last_world := Transform3D.IDENTITY
var _age := 0.0
var _ground_body: StaticBody3D
var _ground_shape := HeightMapShape3D.new()
var _ground_center := Vector2(INF, INF)
var _fallback_height := 0.0
var _heights := PackedFloat32Array()
var _car_hit_area: Area3D
var _damage_dealt := false
var _next_car_hit := 0.0


func launch(source: Node3D, simulator: PhysicalBoneSimulator3D, root: PhysicalBone3D, source_world: World, source_car: Car_Movement, push: Vector3) -> void:
	target = source
	world = source_world
	car = source_car
	root_bone = root
	target.tree_exiting.connect(queue_free)

	var skeleton := simulator.get_parent() as Skeleton3D
	var shape_scale := skeleton.global_transform.basis.get_scale().x if skeleton else 1.0
	for node in simulator.find_children("*", "PhysicalBone3D", true, false):
		bones.append(node as PhysicalBone3D)
	if root_bone == null and not bones.is_empty():
		root_bone = bones[0]

	_configure_bones(shape_scale)
	if skeleton:
		_attach_free_bones(skeleton)

	_last_world = world.world.global_transform
	_create_ground()
	_create_car_hit_area()
	var start_local := _local_position(root_bone.global_position)
	var ground := _ground_height(start_local.x, start_local.z)
	_fallback_height = ground if is_finite(ground) else start_local.y - 0.5
	_update_ground(start_local)

	simulator.physical_bones_start_simulation()

	_set_velocity(_car_forward() * _car_speed() * inherit_speed + push + Vector3.UP * launch_up_speed, _random_vector() * launch_spin)


func _set_velocity(linear: Vector3, angular: Vector3) -> void:
	for bone in bones:
		PhysicsServer3D.body_set_state(bone.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, linear)
		PhysicsServer3D.body_set_state(bone.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, angular)


func _configure_bones(shape_scale: float) -> void:
	var volumes: Array[float] = []
	var total_volume := 0.0
	for bone in bones:
		var volume := 0.0
		for child in bone.get_children():
			var collision := child as CollisionShape3D
			if collision == null or collision.shape == null:
				continue
			collision.shape = _scaled_shape(collision.shape, shape_scale)
			collision.position *= shape_scale
			volume += _shape_volume(collision.shape)
		volumes.append(volume)
		total_volume += volume

	for i in bones.size():
		var bone := bones[i]
		bone.collision_layer = BONE_LAYER
		bone.collision_mask = BONE_MASK
		bone.friction = friction
		bone.bounce = bounce
		bone.linear_damp = linear_damp
		bone.angular_damp = angular_damp
		bone.mass = maxf(total_mass * volumes[i] / total_volume, 0.2) if total_volume > 0.0 else total_mass / bones.size()
		bone.set("joint_constraints/twist_span", minf(float(bone.get("joint_constraints/twist_span")), twist_span))


func _attach_free_bones(skeleton: Skeleton3D) -> void:
	var simulated := {}
	for bone in bones:
		simulated[skeleton.find_bone(bone.bone_name)] = true

	var follower := Free_Bone_Follower.new()
	for i in skeleton.get_bone_count():
		if simulated.has(i) or skeleton.get_bone_parent(i) >= 0:
			continue
		var pose := skeleton.get_bone_global_pose(i)
		var anchor := -1
		var best := INF
		for j in simulated:
			var distance := pose.origin.distance_squared_to(skeleton.get_bone_global_pose(j).origin)
			if distance < best:
				best = distance
				anchor = j
		if anchor >= 0:
			follower.add(i, anchor, skeleton.get_bone_global_pose(anchor).affine_inverse() * pose)
	if not follower.is_empty():
		skeleton.add_child(follower)


func _scaled_shape(shape: Shape3D, factor: float) -> Shape3D:
	var copy := shape.duplicate() as Shape3D
	if copy is CapsuleShape3D:
		(copy as CapsuleShape3D).radius *= factor
		(copy as CapsuleShape3D).height *= factor
	elif copy is SphereShape3D:
		(copy as SphereShape3D).radius *= factor
	elif copy is BoxShape3D:
		(copy as BoxShape3D).size *= factor
	elif copy is CylinderShape3D:
		(copy as CylinderShape3D).radius *= factor
		(copy as CylinderShape3D).height *= factor
	return copy


func _shape_volume(shape: Shape3D) -> float:
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return PI * capsule.radius * capsule.radius * maxf(capsule.height - capsule.radius * 2.0, 0.0) + 4.0 / 3.0 * PI * pow(capsule.radius, 3.0)
	if shape is SphereShape3D:
		return 4.0 / 3.0 * PI * pow((shape as SphereShape3D).radius, 3.0)
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return size.x * size.y * size.z
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return PI * cylinder.radius * cylinder.radius * cylinder.height
	return 0.0


func _physics_process(delta: float) -> void:
	if world == null or root_bone == null:
		return

	_age += delta

	var current_world := world.world.global_transform
	var shift := current_world * _last_world.affine_inverse()
	for bone in bones:
		var rid := bone.get_rid()
		var bone_transform: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
		var linear: Vector3 = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
		var angular: Vector3 = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, shift * bone_transform)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, shift.basis * linear)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, shift.basis * angular)
	_last_world = current_world

	var root_position: Vector3 = (PhysicsServer3D.body_get_state(root_bone.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D).origin
	_car_hit_area.global_position = root_position
	var local := _local_position(root_position)
	_update_ground(local)

	if _should_despawn(local):
		target.queue_free()


func _local_position(global_point: Vector3) -> Vector3:
	return _last_world.affine_inverse() * global_point

# ============================ GROUND ==========================================

func _create_ground() -> void:
	_ground_body = StaticBody3D.new()
	_ground_body.collision_layer = GROUND_LAYER
	_ground_body.collision_mask = 0
	var material := PhysicsMaterial.new()
	material.friction = friction
	_ground_body.physics_material_override = material
	var collision := CollisionShape3D.new()
	collision.shape = _ground_shape
	_ground_body.add_child(collision)
	add_child(_ground_body)


func _update_ground(local_position: Vector3) -> void:
	var center := Vector2(local_position.x, local_position.z)
	if _ground_center.distance_to(center) < ground_recenter_distance:
		return

	_ground_center = center.round()

	var size := ground_patch_cells + 1
	var half: int = floori(ground_patch_cells / 2.0)
	_heights.resize(size * size)

	for iz in size:
		for ix in size:
			var h := _ground_height(_ground_center.x + ix - half, _ground_center.y + iz - half)
			_heights[iz * size + ix] = h if is_finite(h) else _fallback_height

	_ground_shape.map_width = size
	_ground_shape.map_depth = size
	_ground_shape.map_data = _heights
	_ground_body.position = Vector3(_ground_center.x, 0.0, _ground_center.y)


func _ground_height(x: float, z: float) -> float:
	if world == null or world.ground == null:
		return INF
	return world.ground.ground_height(x, z)

# ============================ CAR HIT =========================================

func _create_car_hit_area() -> void:
	_car_hit_area = Area3D.new()
	_car_hit_area.top_level = true
	_car_hit_area.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_car_hit_area.collision_layer = 0
	_car_hit_area.monitorable = false
	var sphere := SphereShape3D.new()
	sphere.radius = car_hit_radius
	var collision := CollisionShape3D.new()
	collision.shape = sphere
	_car_hit_area.add_child(collision)
	add_child(_car_hit_area)
	_car_hit_area.global_position = root_bone.global_position
	_car_hit_area.body_entered.connect(_on_car_hit_area_body_entered)


func _on_car_hit_area_body_entered(other: Node3D) -> void:
	var hit_car := other as Car_Movement
	if hit_car == null or _age < maxf(car_hit_arm_time, _next_car_hit) or hit_car.speed < car_hit_min_speed:
		return
	_next_car_hit = _age + car_hit_cooldown

	var hit_position := _car_hit_area.global_position

	if not _damage_dealt:
		_damage_dealt = true
		Events.player_take_damage.emit(car_hit_damage, hit_position)
		hit_car.spawn_hit_effect(hit_position, car_hit_effect_scale)
		hit_car.apply_impact_speed_loss(car_hit_speed_loss)

	var side := signf(hit_car.global_transform.basis.x.dot(hit_position - hit_car.global_position))
	if side == 0.0:
		side = 1.0 if randf() < 0.5 else -1.0

	_set_velocity(
		_car_forward() * hit_car.speed * car_hit_launch_ratio
			+ Vector3.UP * car_hit_launch_up
			+ hit_car.global_transform.basis.x * side * car_hit_launch_side,
		_random_vector() * car_hit_spin)

# ============================ HELPERS =========================================

func _should_despawn(local_position: Vector3) -> bool:
	if _age > max_lifetime:
		return true
	if local_position.y < _fallback_height - fall_limit:
		return true
	if car and root_bone.global_position.distance_to(car.global_position) > despawn_distance:
		return true
	if car and (car.global_transform.affine_inverse() * root_bone.global_position).z > despawn_behind:
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


class Free_Bone_Follower extends SkeletonModifier3D:
	var _bones: PackedInt32Array = []
	var _anchors: PackedInt32Array = []
	var _offsets: Array[Transform3D] = []

	func add(bone: int, anchor: int, offset: Transform3D) -> void:
		_bones.append(bone)
		_anchors.append(anchor)
		_offsets.append(offset)

	func is_empty() -> bool:
		return _bones.is_empty()

	func _process_modification_with_delta(_delta: float) -> void:
		var skeleton := get_skeleton()
		if skeleton == null:
			return
		for i in _bones.size():
			skeleton.set_bone_global_pose(_bones[i], skeleton.get_bone_global_pose(_anchors[i]) * _offsets[i])
