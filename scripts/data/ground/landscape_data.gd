extends Resource
class_name LandscapeData

@export var shoulder_texture: Texture2D
@export var meadow_texture: Texture2D
@export var forest_texture: Texture2D
@export var forest_tint := Color(0.75, 0.75, 0.75)

@export var shoulder_width := 3.0
@export var shoulder_fade := 10.0

@export var forest_foot_height := 8.0
@export var forest_full_height := 22.0
@export var plains_forest_frequency := 0.004
@export_range(0.0, 1.0, 0.01) var plains_forest_threshold := 0.64
@export_range(0.0, 0.5, 0.01) var forest_edge_noise := 0.15

@export_range(4, 32, 1) var grid_cells_per_chunk := 13
@export var grid_margin := 1.0

@export var vegetation_categories: Array[VegetationCategoryData] = []
