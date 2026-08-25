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
@export var tire_trail_manager: Tire_trail_manager
@export var blood_trail_manager: Tire_trail_manager
@export var lightning_controller: LightningController
@export var enemy_spawner: Enemy_spawner

@onready var enemy_encounter: Enemy_Encounter = $"../../Enivironment/EnemyEncounter"


const START_DISTANCE := 5.0
const DISTANCE_TO_END := 200.0
const OBSTACLE_SPAWN_CHANCE = 0.05

func _ready() -> void:
	set_world()
	set_player_car()
	set_weapon_system()
	set_road_manager()
	set_road_generator()
	
	car.player_status_controller.initialize()
	
	road_generator.obstacle_spawn_chance = OBSTACLE_SPAWN_CHANCE
	road_generator.initialize(world.road_set, world.obstacle_set)
	vegetation_scatter.initialize()
	ground_generator.initialize()
	road_manager.initialize(START_DISTANCE)
	
	set_road_generator()
	
	run_manager.initialize(DISTANCE_TO_END)
	
	enemy_encounter.inialize()
	#enemy_encounter.start_encounter()
	
	tire_trail_manager.initialize(world, car, road_manager)
	blood_trail_manager.initialize(world, car, road_manager)

	queue_free()



func set_world():
	road_generator.world = world
	ground_generator.world = world
	ground_generator.vegetation = vegetation_scatter
	road_manager.world = world
	ProjectileSpawner.world = world
	lightning_controller.world = world
	enemy_spawner.world = world

func set_road_manager():
	weather_generator.road_manager = road_manager
	
func set_road_generator():
	weather_generator.road_generator = road_generator
	enemy_spawner.road_generator = road_generator

func set_player_car():
	road_manager.car_movement = car

func set_weapon_system():
	car.weapon_controller.initialize()
	
