extends CharacterBody3D
class_name Car_Movement

var speed := 0.0
var lane_offset := 0.0
var lateral_velocity := 0.0
var last_lateral_velocity := 0.0


var steering_input := 0.0


@export_category("Movement")
@export var drag := 15.0
@export var brake := 50.0
@export var max_speed := 80.0
@export var acceleration := 30.0
@export var acceleration_curve: Curve


@export_category("Strafe")
@export var max_offset := 4.0
@export var strafe_speed := 8.0
@export var steering_curve: Curve
@export var min_strafe_speed := 2.0


@export_category("Road Influence")
@export var road_turn_force := 0.5


@export_category("Dodge")
@export var dodge_force := 12.0
@export var dodge_distance := 2.0
@export var dodge_min_speed := 40.0
@export var dodge_window := 0.35
@export var dodge_hit_radius := 1.2
@export var dodge_damage := 20.0
@export var dodge_knockback_force := 15.0
@export var enemy_detection_mask: int = 1

var dodge_timer := 0.0
var dodge_direction := 0.0
var dodge_already_hit: Array[Node] = []


@export_category("Strafe Physics")
@export var spring := 30.0
@export var damping := 8.0


@export_category("Hit")
@export var base_damage := 15


@export_category("Exports")
@export var player_cam: Camera3D
@export var back_lights: BackLights

@export var cam_pivot: Node3D
@export var inventory: Inventory
@export var weapon_pivot: Node3D
@export var visual_effects: Car_Visual_Effects
@export var weapon_controller: Weapon_controller
@export var player_status_controller: Player_Status_Controller

var road_manager: Road_manager


func initialize(initial_speed: float):
	speed = initial_speed


func _ready() -> void:
	InputController.dodge.connect(dodge)


func _physics_process(delta: float) -> void:
	get_input()
	process_speed(delta)
	process_strafe(delta)
	process_visuals(delta)
	process_enemies_hits()
	process_dodge_hit_check(delta)
	
	#print("Speed: ", speed)
	#print("Lane offset: ", lane_offset)
	#print("Lateral velosity: ", lateral_velocity)


func process_enemies_hits() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()

		if collider.is_in_group("Enemy"):
			var hit_data := create_hit_data(collision.get_position(), collision.get_normal())
			collider.on_car_hit(hit_data)


func create_hit_data(contact_point: Vector3, contact_normal: Vector3) -> HitData:
	var car_velocity := -global_transform.basis.z * speed
	return HitData.new(self, car_velocity, contact_point, contact_normal, base_damage)


func get_input() -> void:
	steering_input = InputController.steering


func process_speed(delta: float) -> void:
	if InputController.accelerating:
		var acceleration_mul = get_acceleration_multiplier()
		speed += acceleration * acceleration_mul * delta

	if InputController.braking:
		speed -= brake * delta
		back_lights.turn_on()
	else:
		back_lights.turn_off()

	speed -= drag * delta
	speed = clamp(speed, 0.0, max_speed)


func process_strafe(delta: float) -> void:
	if speed >= min_strafe_speed:
		var steering_mul := get_steering_multiplier()

		lane_offset += steering_input * strafe_speed * steering_mul * delta

		var road_offset := get_road_turn_offset()
		lane_offset += road_offset * delta

	lane_offset = clamp_offset()

	var error := lane_offset - position.x

	lateral_velocity += error * spring * delta
	lateral_velocity *= exp(-damping * delta)

	position.x += lateral_velocity * delta


func get_road_turn_offset() -> float:
	return -road_manager.smoothed_turn_velocity * road_turn_force


func process_visuals(delta: float) -> void:
	visual_effects.process_visual_tilt(delta, lateral_velocity, road_manager.smoothed_turn_velocity)


func get_speed_ratio() -> float:
	return clampf(speed / max_speed, 0.0, 1.0)


func get_acceleration_multiplier() -> float:
	return acceleration_curve.sample_baked(get_speed_ratio())


func get_steering_multiplier() -> float:
	return steering_curve.sample_baked(get_speed_ratio())


func clamp_offset() -> float:
	return clamp(lane_offset, -max_offset, max_offset)


func dodge() -> void:
	if steering_input == 0.0 or speed < dodge_min_speed:
		return
	
	var direction = sign(steering_input)
	
	lane_offset += direction * dodge_distance
	lane_offset = clamp_offset()
	
	lateral_velocity += direction * dodge_force
	
	dodge_direction = direction
	dodge_timer = dodge_window
	dodge_already_hit.clear()


func process_dodge_hit_check(delta: float) -> void:
	if dodge_timer <= 0.0:
		return
	
	dodge_timer -= delta
	_check_dodge_hit(dodge_direction)


func _check_dodge_hit(direction: float) -> void:
	var space_state := get_world_3d().direct_space_state
	
	var shape := BoxShape3D.new()
	shape.size = Vector3(dodge_hit_radius * 2.0, 2.0, dodge_hit_radius * 2.0)
	
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = enemy_detection_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	
	var results := space_state.intersect_shape(query)
	
	for result in results:
		var enemy := _resolve_enemy(result.collider)
		if enemy == null:
			continue
		if enemy in dodge_already_hit:
			continue
		
		var knockback := Vector3(direction * dodge_knockback_force, 0.0, 0.0)
		enemy.on_dodge_hit(dodge_damage, knockback)
		dodge_already_hit.append(enemy)


func _resolve_enemy(node: Node) -> Encounter_Enemy:
	var current := node
	while current:
		if current is Encounter_Enemy:
			return current
		current = current.get_parent()
	return null
