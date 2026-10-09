extends Node

@export var game_viewport: SubViewport
@export var view_container: SubViewportContainer

@export var ui: main_UI
@export var world: World
@export var car: Car_Movement

@export var run_manager: Run_manager
@export var road_manager: Road_manager
@export var enemy_spawner: Enemy_spawner
@export var sky_controller: SkyController
#@export var fog_controller: FogController
@export var road_generator: Road_generator
@export var ground_generator: Ground_generator
@export var weather_generator: Weather_generator
@export var vegetation_scatter: Vegetation_scatter
@export var tire_trail_manager: Tire_trail_manager
@export var blood_trail_manager: Tire_trail_manager
#@export var speed_trail_manager: Speed_trail_manager
@export var lightning_controller: LightningController

@export var loading_rect: LoadingScreen

@export var aim_controller: Aim_Controller
@export var enemy_encounter: Enemy_Encounter
@export var encounter_director: Encounter_Director

const START_SPEED = 40.0
const START_DISTANCE := 5.0
const DISTANCE_TO_END := 325.0
const OBSTACLE_SPAWN_CHANCE = 0.05

func _ready() -> void:
	Settings.register_viewport(game_viewport, view_container)
	Settings.register_hud(ui.hud)
	set_world()
	GrenadeSpawner.enemy_encounter = enemy_encounter
	set_player_car()
	set_weapon_system()
	set_road_manager()
	set_road_generator()
	set_aim_controller()

	car.player_status_controller.initialize()
	car.initialize(START_SPEED)

	ui.hud.initialize(car)

	road_generator.obstacle_spawn_chance = OBSTACLE_SPAWN_CHANCE
	road_generator.initialize(world.road_set, world.obstacle_set)
	vegetation_scatter.initialize()
	ground_generator.initialize()
	road_manager.initialize(START_DISTANCE)

	set_road_generator()

	run_manager.initialize(DISTANCE_TO_END)
	
	tire_trail_manager.initialize(world, car, road_manager)
	blood_trail_manager.initialize(world, car, road_manager)
	#speed_trail_manager.initialize(world, car)
	
	#UpgradeManager.purchase(UpgradeManager.database.upgrades[0])

	enemy_encounter.inialize(world)
	set_encounter()
	
	encounter_director.initialize(enemy_encounter, run_manager)

	#InputController.test_boost.connect(BoostManager.activate_test_boost)

	await get_tree().process_frame
	
	loading_rect.on_start()
	ui.hud.on_start()

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
	world.ground = ground_generator


func set_road_manager():
	car.road_manager = road_manager
	weather_generator.road_manager = road_manager


func set_road_generator():
	enemy_spawner.road_generator = road_generator
	weather_generator.road_generator = road_generator


func set_player_car():
	aim_controller.car = car
	road_manager.car_movement = car
	GrenadeSpawner.car = car
	enemy_encounter.player = car


func set_weapon_system():
	car.weapon_controller.initialize()


func set_encounter():
	ui.hud.enemy_compass.encounter = enemy_encounter


func set_aim_controller():
	ui.hud.second_rectile.aim_controller = aim_controller
