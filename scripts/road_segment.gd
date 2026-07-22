extends Node3D
class_name Road_segment

@onready var anchor: Marker3D = $Anchor
@onready var origin: Marker3D = $Origin

@export var weight := 1.0
@export var segment_type: RoadTypes.Type

#@onready var area_3d: Area3D = $Area3D
@onready var select_indicator: MeshInstance3D = $SelectIndicator

signal on_enter(segment: Road_segment)

var length: float

func _ready() -> void:
	#area_3d.body_entered.connect(_on_trigger_body_entered)
	length = origin.position.distance_to(anchor.position)

func set_debug_selected(selected: bool):
	if selected:
		select_indicator.visible = true
	else:
		select_indicator.visible = false
