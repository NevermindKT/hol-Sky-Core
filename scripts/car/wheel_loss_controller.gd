extends Node
class_name Wheel_Loss_Controller

static var current: Wheel_Loss_Controller

@export var car: Car_Movement
@export var detached_wheel_scene: PackedScene
@export var hub_sparks_scene: PackedScene

@export_category("Loss")
@export_range(0.0, 1.0, 0.01) var health_threshold := 0.35
@export_range(0.0, 1.0, 0.01) var max_speed_multiplier := 0.85
@export_range(0.0, 1.0, 0.01) var acceleration_multiplier := 0.8
@export_range(0.0, 1.0, 0.01) var steering_pull := 0.15

@export_category("Break Effect")
@export var break_effect_scale := 2.0
@export var break_camera_shake := 12.0
@export var hub_height := -0.3
@export var sparks_full_speed := 50.0

@export_category("Repair")
@export_range(0.0, 1.0, 0.01) var heal_ratio := 0.3

var _last_health := INF
var _hub_sparks: GPUParticles3D


func _ready() -> void:
	current = self
	Events.player_health_changed.connect(_on_player_health_changed)


func _process(_delta: float) -> void:
	if _hub_sparks:
		_hub_sparks.amount_ratio = clampf(car.speed / sparks_full_speed, 0.0, 1.0)
		_hub_sparks.emitting = car.speed > car.min_strafe_speed


func _exit_tree() -> void:
	if current == self:
		current = null


func has_missing_wheel() -> bool:
	return car.wheels.missing_wheel != null


func repair() -> void:
	if not has_missing_wheel():
		return

	car.wheels.restore_missing_wheel()
	car.visual_effects.clear_missing_wheel()
	car.max_speed_multiplier = 1.0
	car.acceleration_multiplier = 1.0
	car.steering_bias = 0.0
	_stop_hub_sparks()

	Events.player_heal.emit(car.player_status_controller.max_health * heal_ratio)


func _on_player_health_changed(value: float) -> void:
	var threshold := car.player_status_controller.max_health * health_threshold

	if value < threshold and _last_health >= threshold and not has_missing_wheel():
		_lose_wheel()

	_last_health = value


func _lose_wheel() -> void:
	var pivot := car.wheels.detach_random_wheel()
	if pivot == null:
		return

	car.visual_effects.set_missing_wheel(pivot.position)
	car.max_speed_multiplier = max_speed_multiplier
	car.acceleration_multiplier = acceleration_multiplier
	car.steering_bias = signf(pivot.position.x) * steering_pull

	_play_break_effect(pivot)
	_spawn_detached_wheel(pivot)


func _play_break_effect(pivot: Node3D) -> void:
	var hub_position := pivot.global_position

	car.spawn_hit_effect(hub_position, break_effect_scale)
	if car.player_cam:
		car.player_cam.apply_incoming_hit(hub_position, break_camera_shake)

	if hub_sparks_scene:
		_hub_sparks = hub_sparks_scene.instantiate() as GPUParticles3D
		pivot.add_child(_hub_sparks)
		_hub_sparks.position = Vector3(0.0, hub_height, 0.0)


func _stop_hub_sparks() -> void:
	if _hub_sparks == null:
		return

	var sparks := _hub_sparks
	_hub_sparks = null
	sparks.emitting = false
	get_tree().create_timer(sparks.lifetime).timeout.connect(sparks.queue_free)


func _spawn_detached_wheel(pivot: Node3D) -> void:
	if detached_wheel_scene == null or car.road_manager == null or car.road_manager.world == null:
		return

	var world := car.road_manager.world
	var wheel := detached_wheel_scene.instantiate() as Detached_Wheel
	world.world.add_child(wheel)
	wheel.launch(world, car, car.wheels.get_wheel_mesh(pivot).global_transform, signf(pivot.position.x))
