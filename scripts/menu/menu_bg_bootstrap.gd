extends Node

@export var world: World
@export var road_gen: Road_generator
@export var ground_gen: Ground_generator
@export var veg_gen: Vegetation_scatter
@export var sky_controller: SkyController

func _ready() -> void:
	road_gen.world = world
	ground_gen.world = world
	ground_gen.vegetation = veg_gen
	sky_controller.world = world

	world.ground = ground_gen

	road_gen.initialize(world.road_set, world.obstacle_set)
	veg_gen.initialize()
	ground_gen.initialize()

	Events.run_started.emit()
