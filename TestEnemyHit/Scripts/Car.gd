extends CharacterBody3D

@export var move_speed := 8.0
@export var max_x := 3.0
@export var hit_damage := 15.0

func _physics_process(_delta: float) -> void:
	move()

func move() -> void:
	var direction := Input.get_axis("move_left", "move_right")

	velocity = Vector3(direction * move_speed, 0.0, 0.0)

	move_and_slide()

	global_position.x = clamp(global_position.x, -max_x, max_x)

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()

		if collider.is_in_group("Enemy"):
			var hit_data := create_hit_data(collision.get_position(), collision.get_normal())
			collider.on_car_hit(hit_data)

## Факти про удар цієї машини. Витягнуто в окремий метод, бо їх потрібно
## будувати з двох сторін: коли машина сама в'їжджає у ворога (цикл вище)
## і коли ворог сам налітає на нерухому машину (EnemyController викликає
## цей метод напряму зі свого зіткнення).
func create_hit_data(contact_point: Vector3, contact_normal: Vector3) -> HitData:
	return HitData.new(self, velocity, contact_point, contact_normal, hit_damage)
