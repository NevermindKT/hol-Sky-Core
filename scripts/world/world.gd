extends Node
class_name World

@onready var world: Node3D = $World
@onready var world_path: Path3D = $WorldPath
@onready var projectiles: Node3D = $Projectiles
@onready var road_container: Node3D = $World/RoadContainer
@onready var path_follow_3d: PathFollow3D = $WorldPath/PathFollow3D

var last_world_basis: Basis

func _ready():
	last_world_basis = world.global_transform.basis
