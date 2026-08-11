extends Node

@onready var car: Car_Movement = $"../../Car"
@onready var hud: CanvasLayer = $"../../UI/HUD"
@onready var world: World = $"../../Enivironment/World"

@onready var run_manager: Run_manager = $"../RunManager"
@onready var road_manager: Road_manager = $"../RoadManager"
@onready var road_generator: Road_generator = $"../RoadGenerator"

const START_DISTANCE := 5.0
const DISTANCE_TO_END := 200.0

func _ready() -> void:
	set_world()
	set_player_car()
	set_weapon_system()
	
	road_generator.initialize(world.road_set)
	road_manager.initialize(START_DISTANCE)
	run_manager.initialize(DISTANCE_TO_END)
	
	queue_free()


func set_world():
	road_generator.world = world
	road_manager.world = world
	ProjectileSpawner.world = world


func set_player_car():
	road_manager.car_movement = car


func set_weapon_system() -> void:
	car.weapon_controller.initialize()
