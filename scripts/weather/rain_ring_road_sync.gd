extends GPUParticles3D

# Синхронізація кілець дощу з дорогою.
#
# ВАЖЛИВО: не можна напряму копіювати RoadManager.world.world.global_transform
# сюди щокадру — цей трансформ "сирий" і необмежено дрейфує в абсолютних
# координатах разом з progress по PathFollow3D (дорожні сегменти цього
# уникають лише завдяки власному локальному офсету всередині RoadContainer,
# який компенсує дрейф). Якщо скопіювати його напряму, цей вузол сам стане
# "далеким" від камери з часом, і Godot почне відсікати всю систему по
# visibility_aabb, навіть якщо самі частинки рендеряться в правильному місці.
#
# Замість цього накопичуємо лише ДЕЛЬТУ (зміну за кадр) поверх поточної
# позиції вузла — так RainRings назавжди лишається біля своєї початкової,
# близької до камери позиції, точно як дорожні сегменти.

var _prev_world_transform: Transform3D
var _initialized := false

func _process(_delta: float) -> void:
	if RoadManager.world == null:
		return

	var current_world_transform: Transform3D = RoadManager.world.world.global_transform

	if not _initialized:
		_prev_world_transform = current_world_transform
		_initialized = true
		return

	var delta_transform := current_world_transform * _prev_world_transform.affine_inverse()
	global_transform = delta_transform * global_transform

	_prev_world_transform = current_world_transform
