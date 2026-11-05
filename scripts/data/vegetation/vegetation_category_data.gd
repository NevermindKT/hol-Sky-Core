extends Resource
class_name VegetationCategoryData

enum Placement { SCATTER, GRID }

@export var category_name: String = ""
@export var placement: Placement = Placement.SCATTER
@export var footprint_radius := 0.0
@export_dir var folder_path: String = ""
@export var include_patterns: PackedStringArray = PackedStringArray()
@export var exclude_patterns: PackedStringArray = PackedStringArray()

@export var density := 1.0
@export var forest_response: Curve
@export var min_road_distance := 10.0
@export var road_fade_distance := 10.0
@export var max_road_distance := 240.0

@export var variants_per_chunk: int = 3
@export var scale_range := Vector2(0.85, 1.25)
@export var ground_sink := 0.0

@export var visibility_range := 0.0
@export var visibility_fade := true
@export var shrink_distance := Vector2.ZERO
@export var cast_shadows := true
@export var lod_bias := 1.0
@export var lod_road_distances: PackedFloat32Array = PackedFloat32Array()
@export var lod_keep_ratios: PackedFloat32Array = PackedFloat32Array()

@export_range(0.0, 1.0, 0.01) var alpha_cutoff := 0.4
@export_range(0.0, 1.0, 0.01) var specular := 0.1
@export var wind_strength := 0.0
@export var wind_speed := 1.0
@export_range(0.0, 1.0, 0.01) var normal_up_blend := 0.0


@export_group("Crowd LOD")
## Радиус окрестности в ячейках сетки (1 = 3x3). Больше 1 неточно на краях чанка.
@export_range(1, 3, 1) var crowd_radius := 1
## Доля занятых соседних ячеек, с которой дерево считается «окружённым». 0 = выключено.
@export_range(0.0, 1.0, 0.01) var crowd_lod_threshold := 0.6
## На сколько тиров LOD сдвигать окружённое дерево.
@export_range(0, 4, 1) var crowd_lod_bump := 1
## Доля, с которой окружённое дерево не рисуется совсем. 0 = выключено.
@export_range(0.0, 1.0, 0.01) var crowd_cull_threshold := 0.9
## Ближе этого расстояния до дороги правило не действует (опушка остаётся детальной).
@export var crowd_min_road_distance := 40.0


func weight_for(forest: float, road_distance: float) -> float:
	var weight := 1.0
	if forest_response:
		weight = clampf(forest_response.sample(forest), 0.0, 1.0)
	weight *= smoothstep(min_road_distance, min_road_distance + road_fade_distance, road_distance)
	if max_road_distance > 0.0:
		weight *= 1.0 - smoothstep(max_road_distance - road_fade_distance, max_road_distance, road_distance)
	return weight
