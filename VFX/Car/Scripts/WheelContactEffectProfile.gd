extends Resource
class_name WheelContactEffectProfile

# Гравітацією по осі X можна буде налаштовувати симуляцію більшої швидкості,
# що пилюка ще далі розпилюється

@export_group("Appearance")
@export var color: Color = Color.WHITE
@export var particle_size: float = 0.2
@export var mesh: Mesh

@export_group("Emission")
@export var amount: int = 32
@export var lifetime: float = 0.6


@export_group("Movement")
@export var direction: Vector3 = Vector3.UP
@export_range(0, 180) var spread: float = 35.0

@export var initial_velocity_min: float = 2.0
@export var initial_velocity_max: float = 2.0
@export var velocity_randomness: float = 0.2

@export var gravity: Vector3 = Vector3(0, -2, 0)
@export var damping_min: float = 2.0
@export var damping_max: float = 2.0
