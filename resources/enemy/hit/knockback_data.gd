extends Resource
class_name KnockbackData

@export_group("Force")
@export var horizontal_force: float = 6.0
@export var vertical_force: float = 2.5

@export_group("Speed influence")
## Швидкість машини (м/с), при якій сила з Force вище застосовується
## як є (множник 1.0). Швидше — сильніший відкид, повільніше — слабший.
@export var reference_speed: float = 30.0
## Мінімальний множник сили, навіть якщо машина ледь рухається — щоб
## удар на швидкості, близькій до нуля, не був зовсім беззубим.
@export var min_force_scale: float = 0.6

@export_group("Timing")
@export var duration: float = 0.6
@export var gravity: float = 12.0
