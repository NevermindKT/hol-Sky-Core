extends CharacterBody3D
class_name EnemyController

enum State { NORMAL, REACTING, DEAD }

@export var knockback_controller: KnockbackController
@export var health: Health
@export var hit_effect_scene: PackedScene
@export var move_speed: float = 5.0

@export_category("Blood decals")
@export var blood_decal_scene: PackedScene
@export var road_blood_splatter_scene: PackedScene
@export var blood_splatter_count: int = 3
@export var blood_splatter_radius: float = 1.2
@export var road_blood_forward_offset: float = 1.0
@export var car_blood_scale_range: Vector2 = Vector2(0.5, 0.9)
@export var road_blood_scale_range: Vector2 = Vector2(0.8, 1.6)

const ROAD_COLLISION_MASK := 2

@export var detection_range: float = 40.0
@export var road_lateral_limit: float = 4.0

@export var despawn_behind_distance: float = 40.0

#@export var world_scroll_speed: float = 0.0
@export var corpse_lifetime: float = 5.0

var _state: State = State.NORMAL
var _car: Node3D

var road_generator: Road_generator

var world: World

func _ready() -> void:
	if knockback_controller:
		knockback_controller.setup(self)
		knockback_controller.reaction_finished.connect(_on_reaction_finished)

func _physics_process(_delta: float) -> void:
	_check_despawn()

	if _state == State.NORMAL:
		move()

func move() -> void:
	var direction := Vector3.ZERO
	var car := _get_car()
	if car:
		var to_car := car.global_position - global_position
		to_car.y = 0.0
		var distance := to_car.length()
		if distance > 0.0001 and distance <= detection_range:
			direction = to_car.normalized()

	velocity = direction * (move_speed) # + world_scroll_speed)
	move_and_slide()

	if direction != Vector3.ZERO:
		_clamp_to_road()

	if direction.length_squared() > 0.0001:
		look_at(global_position + direction, Vector3.UP)

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()

		if collider.is_in_group("Car") and collider.has_method("create_hit_data"):
			var hit_data: HitData = collider.create_hit_data(collision.get_position(), collision.get_normal())
			on_car_hit(hit_data)
			break

func on_car_hit(hit_data: HitData) -> void:
	if _state != State.NORMAL:
		return

	if knockback_controller == null:
		push_warning("Enemy: KnockbackController не призначено, удар проігноровано")
		return

	if health:
		health.take_damage(hit_data.damage)

	_spawn_hit_effect(hit_data)
	_spawn_blood_decals(hit_data)

	_state = State.REACTING
	knockback_controller.apply_hit(hit_data)

func _on_reaction_finished() -> void:
	if health and health.is_dead():
		_state = State.DEAD
		set_physics_process(false)
		get_tree().create_timer(corpse_lifetime).timeout.connect(queue_free)
	else:
		_state = State.NORMAL

func _spawn_hit_effect(hit_data: HitData) -> void:
	if hit_effect_scene == null:
		return

	var effect := hit_effect_scene.instantiate() as BloodCarHit
	if effect == null:
		push_warning("Enemy: hit_effect_scene не має скрипта BloodCarHit")
		return

	world.enemies.add_child(effect)

	var direction := global_position - hit_data.car.global_position
	effect.play(hit_data.contact_point, direction)


func _spawn_blood_decals(hit_data: HitData) -> void:
	if blood_decal_scene == null or road_blood_splatter_scene == null:
		return

	_spawn_car_blood(hit_data)
	_spawn_road_blood(hit_data)


func _spawn_car_blood(hit_data: HitData) -> void:
	var decal := blood_decal_scene.instantiate() as Blood_decal
	if decal == null:
		push_warning("Enemy: blood_decal_scene не має скрипта Blood_decal")
		return

	var attach_to: Node3D = hit_data.car.get_node_or_null("Visual")
	if attach_to == null:
		attach_to = hit_data.car

	attach_to.add_child(decal)
	decal.place(hit_data.contact_point, hit_data.contact_normal)
	decal.apply_random_scale(car_blood_scale_range)


func _spawn_road_blood(hit_data: HitData) -> void:
	var space_state := get_world_3d().direct_space_state

	var forward := -hit_data.car.global_transform.basis.z
	var splatter_center := hit_data.contact_point + forward * road_blood_forward_offset

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


func _check_despawn() -> void:
	if global_position.z > despawn_behind_distance:
		queue_free()


func _get_car() -> Node3D:
	if _car == null or not is_instance_valid(_car):
		_car = get_tree().get_first_node_in_group("Car")
	return _car


func _clamp_to_road() -> void:
	var segment := _resolve_segment()
	if segment == null:
		return

	var local_point: Vector3 = segment.to_local(global_position)
	var t := segment.closest_t(local_point)
	var road_xform := segment.road_transform_at(t)

	var lateral := (local_point - road_xform.origin).dot(road_xform.basis.x)
	var clamped_lateral := clampf(lateral, -road_lateral_limit, road_lateral_limit)

	if not is_equal_approx(clamped_lateral, lateral):
		var corrected_local := road_xform.origin + road_xform.basis.x * clamped_lateral
		global_position = segment.to_global(corrected_local)


func _resolve_segment() -> Road_segment:
	if road_generator == null:
		return null

	var best: Road_segment = null
	var best_dist := INF

	for segment in road_generator.segments:
		if not is_instance_valid(segment):
			continue

		var dist := segment.global_position.distance_squared_to(global_position)
		if dist < best_dist:
			best_dist = dist
			best = segment

	return best
