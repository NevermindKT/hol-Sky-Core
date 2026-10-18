extends Node
class_name World

@export var world: Node3D
@export var world_path: Path3D
@export var projectiles: Node3D
@export var road_container: Node3D
@export var enemies: Node3D
@export var ground_container: Node3D
@export var path_follow_3d: PathFollow3D
@export var trail_container: Node3D

@export var ground_path: Path3D

@export var road_set: Road_Set
@export var obstacle_set: Obstacles_set

var last_world_basis: Basis
var ground: Ground_generator

func _ready():
	last_world_basis = world.global_transform.basis
