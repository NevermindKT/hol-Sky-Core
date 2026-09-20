extends Node

@export var car: Car_Movement
@export var hud: HUD
@export var world: World

@export var run_manager: Run_manager
@export var road_manager: Road_manager
@export var enemy_spawner: Enemy_spawner
@export var sky_controller: SkyController
@export var road_generator: Road_generator
@export var ground_generator: Ground_generator
@export var weather_generator: Weather_generator
@export var vegetation_scatter: Vegetation_scatter
@export var tire_trail_manager: Tire_trail_manager
@export var blood_trail_manager: Tire_trail_manager
@export var speed_trail_manager: Speed_trail_manager
@export var lightning_controller: LightningController

@export var aim_controller: Aim_Controller
@export var enemy_encounter: Enemy_Encounter
@export var encounter_director: Encounter_Director

const START_SPEED = 40.0
const START_DISTANCE := 5.0
const DISTANCE_TO_END := 200.0
const OBSTACLE_SPAWN_CHANCE = 0.05

func _ready() -> void:
	set_world()
	set_player_car()
	set_weapon_system()
	set_road_manager()
	set_road_generator()
	set_aim_controller()

	car.player_status_controller.initialize()
	car.initialize(START_SPEED)

	road_generator.obstacle_spawn_chance = OBSTACLE_SPAWN_CHANCE
	road_generator.initialize(world.road_set, world.obstacle_set)
	vegetation_scatter.initialize()
	ground_generator.initialize()
	road_manager.initialize(START_DISTANCE)

	set_road_generator()

	run_manager.initialize(DISTANCE_TO_END)
	
	tire_trail_manager.initialize(world, car, road_manager)
	blood_trail_manager.initialize(world, car, road_manager)
	speed_trail_manager.initialize(world, car)
	
	#UpgradeManager.purchase(UpgradeManager.database.upgrades[0])

	enemy_encounter.inialize(world)
	set_encounter()
	
	encounter_director.initialize(enemy_encounter, run_manager)

	#BoostManager.add_owned(load("res://resources/upgrades/boosts/nitro.tres"))
	#BoostManager.activate(load("res://resources/upgrades/boosts/nitro.tres"))
	
	Events.run_started.emit()
	queue_free()


func set_world():
	road_manager.world = world
	enemy_spawner.world = world
	sky_controller.world = world
	road_generator.world = world
	ground_generator.world = world
	ProjectileSpawner.world = world
	lightning_controller.world = world
	ground_generator.vegetation = vegetation_scatter


func set_road_manager():
	car.road_manager = road_manager
	weather_generator.road_manager = road_manager


func set_road_generator():
	enemy_spawner.road_generator = road_generator
	weather_generator.road_generator = road_generator


func set_player_car():
	aim_controller.car = car
	road_manager.car_movement = car


func set_weapon_system():
	car.weapon_controller.initialize()


func set_encounter():
	hud.enemy_compass.encounter = enemy_encounter


func set_aim_controller():
	hud.second_rectile.aim_controller = aim_controller
