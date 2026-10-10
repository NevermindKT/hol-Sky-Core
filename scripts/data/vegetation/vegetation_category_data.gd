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
@export var max_road_distance := 0.0

@export var variants_per_chunk: int = 3
@export var scale_range := Vector2(0.85, 1.25)
@export var ground_sink := 0.0

@export var visibility_range := 0.0
@export var visibility_fade := true
@export var cast_shadows := true
@export var lod_bias := 1.0
@export var lod_road_distances: PackedFloat32Array = PackedFloat32Array()
@export var lod_keep_ratios: PackedFloat32Array = PackedFloat32Array()

@export_range(0.0, 1.0, 0.01) var alpha_cutoff := 0.4
@export_range(0.0, 1.0, 0.01) var specular := 0.1
@export var wind_strength := 0.0
@export var wind_speed := 1.0


func weight_for(forest: float, road_distance: float) -> float:
	var weight := 1.0
	if forest_response:
		weight = clampf(forest_response.sample(forest), 0.0, 1.0)
	weight *= smoothstep(min_road_distance, min_road_distance + road_fade_distance, road_distance)
	if max_road_distance > 0.0:
		weight *= 1.0 - smoothstep(max_road_distance - road_fade_distance, max_road_distance, road_distance)
	return weight
