extends Resource
class_name HealthData

## Скільки здоров'я у ворога — винесено окремо від логіки, за тим самим
## патерном, що й KnockbackData. Різні типи ворогів зможуть мати різні
## HealthData (наприклад, "легкий" vs "тяжкий" ворог) без правок коду.

@export var max_health: float = 40.0
