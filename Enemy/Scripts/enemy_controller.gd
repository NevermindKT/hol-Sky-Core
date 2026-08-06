extends CharacterBody3D

enum State { NORMAL, REACTING, DEAD }

@export var knockback_controller: KnockbackController
@export var health: Health
@export var hit_effect_scene: PackedScene
@export var move_speed: float = 5.0

#@export var world_scroll_speed: float = 0.0
@export var corpse_lifetime: float = 5.0

var _state: State = State.NORMAL
var _car: Node3D

func _ready() -> void:
	if knockback_controller:
		knockback_controller.setup(self)
		knockback_controller.reaction_finished.connect(_on_reaction_finished)

func _physics_process(_delta: float) -> void:
	if _state == State.NORMAL:
		move()

func move() -> void:
	var direction := Vector3.FORWARD
	var car := _get_car()
	if car:
		var to_car := car.global_position - global_position
		to_car.y = 0.0
		if to_car.length_squared() > 0.0001:
			direction = to_car.normalized()

	velocity = direction * (move_speed) # + world_scroll_speed)
	move_and_slide()

	# Капсула симетрична, тому обертання поки нічого візуально не змінює —
	# але коли з'явиться модель з обличчям/анімацією бігу, вона вже буде
	# дивитись у правильний бік без додаткових правок.
	if direction.length_squared() > 0.0001:
		look_at(global_position + direction, Vector3.UP)

	# Машина повідомляє про удар лише коли САМА в'їжджає у ворога. Якщо
	# машина стоїть, а ворог іде на неї сам — це зіткнення побачить тільки
	# ворог власним move_and_slide(), тож перевіряємо це і тут, а не лише
	# в Car.gd.
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

	get_tree().current_scene.add_child(effect)

	var direction := global_position - hit_data.car.global_position
	effect.play(hit_data.contact_point, direction)


func _get_car() -> Node3D:
	if _car == null or not is_instance_valid(_car):
		_car = get_tree().get_first_node_in_group("Car")
	return _car
