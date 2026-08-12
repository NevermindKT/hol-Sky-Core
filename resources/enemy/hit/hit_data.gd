extends RefCounted
class_name HitData

## Сирі фізичні факти про удар машини по ворогу.
## Це стабільний контракт між Car (джерело удару) та KnockbackController
## (той, хто вирішує, що з цим робити). Car лише повідомляє факти й не знає,
## як саме ворог на них відреагує; конкретна реалізація KnockbackController
## сама вирішує, які поля їй потрібні (просте відкидання може ігнорувати
## contact_point, а майбутній ragdoll — навпаки, покладатися саме на нього).

var car: Node3D
var car_velocity: Vector3
var contact_point: Vector3
var contact_normal: Vector3
## Скільки шкоди завдає цей удар. Машина сама вирішує це число (зараз —
## фіксоване, пізніше може залежати від швидкості) і просто повідомляє його,
## так само як інші факти в цьому класі.
var damage: float

func _init(
	p_car: Node3D = null,
	p_car_velocity: Vector3 = Vector3.ZERO,
	p_contact_point: Vector3 = Vector3.ZERO,
	p_contact_normal: Vector3 = Vector3.ZERO,
	p_damage: float = 0.0
) -> void:
	car = p_car
	car_velocity = p_car_velocity
	contact_point = p_contact_point
	contact_normal = p_contact_normal
	damage = p_damage
