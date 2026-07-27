extends Node
class_name World

@onready var road: Node3D = $Road
@onready var world_path: Path3D = $WorldPath
@onready var road_container: Node3D = $Road/RoadContainer
@onready var path_follow_3d: PathFollow3D = $WorldPath/PathFollow3D
