extends CharacterBody3D
class_name EnemyController

enum State { NORMAL, REACTING, DEAD }

@export var knockback_controller: KnockbackController
@export var health: Health
@export var hit_effect_scene: PackedScene
@export var move_speed: float = 5.0

@export var detection_range: float = 40.0
@export var road_lateral_limit: float = 4.0

#@export var world_scroll_speed: float = 0.0
@export var corpse_lifetime: float = 5.0

var _state: State = State.NORMAL
var _car: Node3D

## Призначається ззовні (Enemy_spawner-ом) одразу після інстанціації.
## Потрібен лише для утримання ворога на полотні дороги (пошук найближчого
## сегмента) — логіці переслідування машини не потрібен.
var road_generator: Road_generator

var world: World

func _ready() -> void:
	if knockback_controller:
		knockback_controller.setup(self)
		knockback_controller.reaction_finished.connect(_on_reaction_finished)

func _physics_process(_delta: float) -> void:
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

	# Капсула симетрична, тому обертання поки нічого візуально не змінює —
	# але коли з'явиться модель з обличчям/анімацією бігу, вона вже буде
	# дивитись у правильний бік без додаткових правок.
	if direction.length_squared() > 0.0001:
		look_at(global_position + direction, Vector3.UP)

	# Машина повідомляє про удар лише коли САМА в'їжджає у ворога. Якщо
	# машина стоїть, а ворог іде на неї сам — це зіткнення побачить тільки
	# ворог власним move_and_slide()
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()

		if collider.is_in_group("Car") and collider.has_method("create_hit_data"):
			var hit_data: HitData = collider.create_hit_data(collision.get_position(), collision.get_normal())
			on_car_hit(hit_data)
			break

## Викликається машиною при зіткненні. Enemy розподіляє факти удару між
## своєю системою здоров'я та KnockbackController-ом
func on_car_hit(hit_data: HitData) -> void:
	if _state != State.NORMAL:
		return

	if knockback_controller == null:
		push_warning("Enemy: KnockbackController не призначено, удар проігноровано")
		return

	if health:
		health.take_damage(hit_data.damage)

	_spawn_hit_effect(hit_data)

	_state = State.REACTING
	knockback_controller.apply_hit(hit_data)

## Викликається, коли KnockbackController завершив фізичну реакцію (відліт,
## приземлення тощо). Тут, а не в момент удару, вирішується фінальний стан —
## бо навіть смертельний удар має спершу дограти відкидання.
func _on_reaction_finished() -> void:
	if health and health.is_dead():
		_state = State.DEAD
		set_physics_process(false)
		get_tree().create_timer(corpse_lifetime).timeout.connect(queue_free)
	else:
		_state = State.NORMAL

## Візуальна реакція на удар — окремо від
## KnockbackController-а, щоб будь-яка майбутня реалізація відкидання
## (включно з ragdoll) отримувала цей ефект безкоштовно, без дублювання
## виклику в кожній з них.
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


func _get_car() -> Node3D:
	if _car == null or not is_instance_valid(_car):
		_car = get_tree().get_first_node_in_group("Car")
	return _car


## Підтягує позицію ворога назад у межі road_lateral_limit від центру
## найближчого сегмента дороги. Не чіпає рух "вздовж" дороги — лише
## бічне відхилення, тож ворог і далі вільно наближається до машини.
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


## Найближчий до поточної позиції ворога активний сегмент дороги.
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
