extends Node

@export var car: Car_Movement
@export var hud: CanvasLayer
@export var world: World

@export var run_manager: Run_manager
@export var road_manager: Road_manager
@export var road_generator: Road_generator
@export var ground_generator: Ground_generator
@export var vegetation_scatter: Vegetation_scatter
@export var weather_generator: Weather_generator

const START_DISTANCE := 5.0
const DISTANCE_TO_END := 200.0

func _ready() -> void:
	set_world()
	set_player_car()
	set_weapon_system()
	set_road_manager()
	set_road_generator()
	
	road_generator.initialize(world.road_set)
	vegetation_scatter.initialize()
	ground_generator.initialize()
	road_manager.initialize(START_DISTANCE)
	run_manager.initialize(DISTANCE_TO_END)
	
	queue_free()



func set_world():
	road_generator.world = world
	ground_generator.world = world
	ground_generator.vegetation = vegetation_scatter
	road_manager.world = world
	ProjectileSpawner.world = world

func set_road_manager():
	weather_generator.road_manager = road_manager
	
func set_road_generator():
	weather_generator.road_generator = road_generator

func set_player_car():
	road_manager.car_movement = car


func set_weapon_system() -> void:
	car.weapon_controller.initialize()
