extends Node3D
class_name BloodCarHit


@export var splash: GPUParticles3D
@export_range(10.0, 180.0) var spread: float = 60.0
@export var lifetime: float = 5.0

@export_group("Speed influence")
@export var reference_speed: float = 20.0
@export var min_intensity_scale: float = 0.4
@export var max_intensity_scale: float = 2.0

@export_group("Blood decals")
@export var blood_decal_scene: PackedScene
@export var road_blood_splatter_scene: PackedScene
@export var blood_splatter_count: int = 3
@export var blood_splatter_radius: float = 1.2
@export var road_blood_forward_offset: float = 1.0
@export var car_blood_scale_range: Vector2 = Vector2(0.5, 0.9)
@export var road_blood_scale_range: Vector2 = Vector2(0.8, 1.6)

const ROAD_COLLISION_MASK := 4

var _base_amount: int
var _base_velocity_min: float
var _base_velocity_max: float
var _process_mat: ParticleProcessMaterial

func _ready() -> void:
	splash.one_shot = true
	splash.emitting = false

	var mat := splash.process_material as ParticleProcessMaterial
	if mat:
		mat = mat.duplicate()
		mat.direction = Vector3.FORWARD
		mat.spread = spread
		splash.process_material = mat
		_process_mat = mat

		_base_velocity_min = mat.initial_velocity_min
		_base_velocity_max = mat.initial_velocity_max

	_base_amount = splash.amount

func play(hit_position: Vector3, hit_direction: Vector3, car_speed: float = 0.0, car: Node3D = null, contact_normal: Vector3 = Vector3.UP) -> void:
	global_position = hit_position
	_orient_to(hit_direction)
	
	var speed_scale := 1.0
	if reference_speed > 0.0:
		speed_scale = clampf(car_speed / reference_speed, min_intensity_scale, max_intensity_scale)
	print(speed_scale)
	print(car_speed / reference_speed)
	if _process_mat:
		_process_mat.initial_velocity_min = _base_velocity_min * speed_scale
		_process_mat.initial_velocity_max = _base_velocity_max * speed_scale

	#splash.amount = maxi(1, int(_base_amount * speed_scale))
	splash.restart()

	get_tree().create_timer(lifetime).timeout.connect(queue_free)

	if car != null:
		_spawn_blood_decals(car, hit_position, contact_normal)

func _orient_to(hit_direction: Vector3) -> void:
	var direction := hit_direction
	direction.y = 0.0

	if direction.length_squared() <= 0.0001:
		return

	look_at(global_position + direction, Vector3.UP)

# ============================ BLOOD DECALS ====================================

func _spawn_blood_decals(car: Node3D, contact_point: Vector3, contact_normal: Vector3) -> void:
	if blood_decal_scene == null or road_blood_splatter_scene == null:
		return

	_spawn_car_blood(car, contact_point, contact_normal)
	_spawn_road_blood(car, contact_point)


func _spawn_car_blood(car: Node3D, contact_point: Vector3, contact_normal: Vector3) -> void:
	var decal := blood_decal_scene.instantiate() as Blood_decal
	if decal == null:
		push_warning("BloodCarHit: blood_decal_scene не має скрипта Blood_decal")
		return

	var attach_to: Node3D = car.get_node_or_null("Visual")
	if attach_to == null:
		attach_to = car

	attach_to.add_child(decal)
	decal.place(contact_point, contact_normal)
	decal.apply_random_scale(car_blood_scale_range)


func _spawn_road_blood(car: Node3D, contact_point: Vector3) -> void:
	var space_state := get_world_3d().direct_space_state

	var forward := -car.global_transform.basis.z
	var splatter_center := contact_point + forward * road_blood_forward_offset

	for i in blood_splatter_count:
		var offset := Vector3(
			randf_range(-blood_splatter_radius, blood_splatter_radius),
			0.0,
			randf_range(-blood_splatter_radius, blood_splatter_radius)
		)
		var from := splatter_center + offset + Vector3.UP * 2.0
		var to := splatter_center + offset - Vector3.UP * 2.0

		var query := PhysicsRayQueryParameters3D.create(from, to, ROAD_COLLISION_MASK)
		var result := space_state.intersect_ray(query)

		if result.is_empty():
			continue

		var segment := _find_road_segment(result.collider)
		if segment == null:
			continue

		var splatter := road_blood_splatter_scene.instantiate() as Road_blood_splatter
		if splatter == null:
			continue

		segment.add_child(splatter)
		splatter.place(result.position, result.normal)
		splatter.apply_random_scale(road_blood_scale_range)


func _find_road_segment(node: Node) -> Road_segment:
	var current := node

	while current != null:
		if current is Road_segment:
			return current
		current = current.get_parent()

	return null
