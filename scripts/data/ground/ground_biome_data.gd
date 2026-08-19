extends Resource
class_name GroundBiomeData

@export var biome_name: String = ""

@export var shoulder_texture: Texture2D
@export var ground_texture: Texture2D

@export var shoulder_ground_blend_curve: Curve

@export var height_noise: FastNoiseLite

@export var height_curve: Curve
@export_range(0.0, 10.0, 0.1) var height_amplitude := 1.5

@export var vegetation_categories: Array[VegetationCategoryData] = []
