extends KnockbackController
class_name SimpleKnockbackController

## Прототипна реалізація KnockbackController: кінематичний відкид через
## velocity + move_and_slide() на самому CharacterBody3D ворога.
## Буде замінена/доповнена RagdollKnockbackController-ом пізніше — жодних
## змін в EnemyController чи Car це не потребуватиме.

@export var profile: KnockbackProfile

var _velocity: Vector3
var _time_left: float = 0.0
var _active: bool = false

func _ready() -> void:
	set_physics_process(false)

func apply_hit(hit_data: HitData) -> void:
	if profile == null:
		push_error("SimpleKnockbackController: profile не призначено")
		return
	if body == null:
		push_error("SimpleKnockbackController: body не призначено (забули викликати setup()?)")
		return

	# Напрям "від машини" рахуємо по позиціях, а не по collision normal —
	# так надійніше для прототипу з примітивами. contact_point/contact_normal
	# з hit_data лишаються доступні для майбутніх реалізацій (напр. ragdoll),
	# яким потрібна саме точка контакту.
	var away_from_car := body.global_position - hit_data.car.global_position
	away_from_car.y = 0.0
	var direction := away_from_car.normalized() if away_from_car.length_squared() > 0.0001 else Vector3.FORWARD

	_velocity = direction * profile.horizontal_force + Vector3.UP * profile.vertical_force
	_time_left = profile.duration
	_active = true

	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not _active:
		return

	_velocity.y -= profile.gravity * delta
	body.velocity = _velocity
	body.move_and_slide()
	_velocity = body.velocity

	_time_left -= delta
	if _time_left <= 0.0:
		_active = false
		set_physics_process(false)
		reaction_finished.emit()
