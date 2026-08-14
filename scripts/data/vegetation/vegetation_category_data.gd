extends Resource
class_name VegetationCategoryData

@export var category_name: String = ""
@export_dir var folder_path: String = ""

@export var count: int = 10

@export var variants_per_tile: int = 3

@export var scale_range := Vector2(0.85, 1.25)

## Розподіл густоти відносно дороги. X кривої: 0.0 = біля краю дороги,
## 1.0 = далекий край землі (перед туманом). Y кривої: 0.0 = тут не спавнити,
## 1.0 = найбільша ймовірність спавну тут. Якщо не призначено — розподіл
## рівномірний по всій ширині (як зараз).
@export var density_curve: Curve


@export_range(0.0, 1.0, 0.01) var albedo_darken := 0.4
@export_range(0.0, 1.0, 0.01) var roughness := 1.0
