extends Resource
class_name HealthProfile

## Скільки здоров'я у ворога — винесено окремо від логіки, за тим самим
## патерном, що й KnockbackProfile. Різні типи ворогів зможуть мати різні
## HealthProfile (наприклад, "легкий" vs "тяжкий" ворог) без правок коду.

@export var max_health: float = 40.0
