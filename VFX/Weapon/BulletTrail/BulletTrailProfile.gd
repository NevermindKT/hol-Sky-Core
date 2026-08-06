extends Resource
class_name BulletTrailProfile

@export_group("Mesh")

@export var width: float = 0.03
@export var length: float = 1.0

@export_group("Appearance")

@export var color: Color = Color.WHITE

@export_range(0.05, 1.0)
var tail_width := 0.2

@export_range(0.05, 1.0)
var core_size := 0.25

@export_range(0.1, 2.0)
var glow_size := 1.0

@export_range(0.0, 5.0)
var emission_strength := 1.0
