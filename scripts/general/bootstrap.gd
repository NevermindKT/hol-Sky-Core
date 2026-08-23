extends Node

@onready var car: Car_Movement = $"../../Car"
@onready var hud: CanvasLayer = $"../../UI/HUD"
@onready var world: World = $"../../Enivironment/World"

@onready var run_manager: Run_manager = $"../RunManager"
@onready var road_manager: Road_manager = $"../RoadManager"
@onready var enemy_spawner: Enemy_spawner = $"../EnemySpawner"
@onready var road_generator: Road_generator = $"../RoadGenerator"
@onready var weather_generator: Weather_generator = $"../WeatherGenerator"

@onready var enemy_encounter: Enemy_Encounter = $"../../Enivironment/EnemyEncounter"


const START_DISTANCE := 5.0
const DISTANCE_TO_END := 200.0
const OBSTACLE_SPAWN_CHANCE = 0.05

func _ready() -> void:
	set_world()
	set_player_car()
	set_weapon_system()
	
	car.player_status_controller.initialize()
	
	road_generator.obstacle_spawn_chance = OBSTACLE_SPAWN_CHANCE
	road_generator.initialize(world.road_set, world.obstacle_set)
	road_manager.initialize(START_DISTANCE)
	
	set_road_generator()
	
	weather_generator.initialize(car)
	
	run_manager.initialize(DISTANCE_TO_END)
	
	enemy_encounter.inialize()
	enemy_encounter.start_encounter()
	
	queue_free()


func set_world():
	road_generator.world = world
	road_manager.world = world
	ProjectileSpawner.world = world
	enemy_spawner.world = world


func set_player_car():
	road_manager.car_movement = car


func set_weapon_system():
	car.weapon_controller.initialize()

func set_road_generator():
	enemy_spawner.road_generator = road_generator
