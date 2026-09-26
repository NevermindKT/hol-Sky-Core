extends Resource
class_name VegetationCategoryData

enum Placement { SCATTER, GRID }

@export var category_name: String = ""
@export var placement: Placement = Placement.SCATTER
@export var footprint_radius := 0.0
@export_dir var folder_path: String = ""
@export var include_patterns: PackedStringArray = PackedStringArray()

@export var density := 1.0
@export var forest_response: Curve
@export var min_road_distance := 10.0
@export var road_fade_distance := 10.0

@export var variants_per_chunk: int = 3
@export var scale_range := Vector2(0.85, 1.25)
@export var ground_sink := 0.0

@export var visibility_range := 0.0
@export var cast_shadows := true

var albedo_darken := 0.5
var roughness := 1.0


func weight_for(forest: float, road_distance: float) -> float:
	var weight := 1.0
	if forest_response:
		weight = clampf(forest_response.sample(forest), 0.0, 1.0)
	return weight * smoothstep(min_road_distance, min_road_distance + road_fade_distance, road_distance)
