extends Node

@export var world: World
@export var road_gen: Road_generator
@export var veg_gen: Vegetation_scatter
@export var ground_gen: Ground_generator
@export var sky_controller: SkyController

@export var overlay: TextureRect
@export var sub_viewport: SubViewport
@export var sub_viewport_container: SubViewportContainer


func _ready() -> void:
	Settings.register_viewport(sub_viewport, sub_viewport_container)
	Settings.register_overlay(overlay)
	Settings.register_ps1_overlay_material(overlay.material as ShaderMaterial)

	road_gen.world = world
	ground_gen.world = world
	ground_gen.vegetation = veg_gen
	sky_controller.world = world

	world.ground = ground_gen

	road_gen.initialize(world.road_set, world.obstacle_set)
	veg_gen.initialize()
	ground_gen.initialize()

	Events.run_started.emit()
