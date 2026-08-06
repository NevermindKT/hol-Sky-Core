extends Resource
class_name KnockbackProfile

## Дані для тюнингу реакції ворога на удар, винесені окремо від логіки —
## за тим самим патерном, що й інші *Profile ресурси в проєкті
## (WheelContactEffectProfile, FogProfile тощо). Дизайнер зможе міняти
## силу/тривалість удару без правок коду, а різні KnockbackController-и
## (простий, ragdoll) можуть мати власні профілі з іншими полями.

@export_group("Force")
@export var horizontal_force: float = 6.0
@export var vertical_force: float = 2.5

@export_group("Timing")
@export var duration: float = 0.6
@export var gravity: float = 12.0
