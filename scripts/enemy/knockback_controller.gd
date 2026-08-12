extends Node
class_name KnockbackController

## Базовий контракт реакції ворога на удар машиною.
##
## Це НЕ конкретна реалізація відкидання, а стратегія (composition, не
## наслідування тіла). EnemyController та Car працюють лише через цей
## контракт і нічого не знають про те, як саме ворог реагує на удар.
##
## Щоб додати нову реалізацію (ragdoll, анімовану реакцію тощо) — створи
## новий скрипт `extends KnockbackController`, перевизнач apply_hit(),
## і піджени його на вузол KnockbackController у сцені ворога.

## emit-иться, коли фізична реакція на удар завершена (наприклад, ворог
## долетів і торкнувся землі). Чи удар був смертельним — це питання не до
## KnockbackController-а, а до Health; EnemyController перевіряє це сам
## після цього сигналу.
signal reaction_finished

## CharacterBody3D ворога, яким ця реалізація керує на час реакції.
var body: CharacterBody3D

func setup(p_body: CharacterBody3D) -> void:
	body = p_body

## Викликається EnemyController-ом одразу після удару. Реалізація бере на
## себе керування body на час реакції та в кінці має emit-нути
## reaction_finished.
func apply_hit(_hit_data: HitData) -> void:
	push_error("KnockbackController.apply_hit() not implemented — override in a subclass")
