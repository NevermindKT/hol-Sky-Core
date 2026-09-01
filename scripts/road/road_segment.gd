@tool
extends Node3D
class_name Road_segment

@export var anchor: Marker3D
@export var origin: Marker3D

@export var road_path: Path3D

@export var weight := 1.0
@export var segment_type: RoadType.Type


var obstacle_placement_array: Array[Marker3D] = []

@onready var obstacles: Node = $Obstacles

var polygon: CSGPolygon3D

var length: float

func _ready() -> void:
	assert(origin != null, "Origin missing in " + name)
	assert(anchor != null, "Anchor missing in " + name)
	
	length = origin.position.distance_to(anchor.position)
	
	if obstacles != null:
		for child in obstacles.get_children():
			if child is Marker3D:
				obstacle_placement_array.append(child)

	if road_path:
		polygon = road_path.get_node_or_null("CSGPolygon3D") as CSGPolygon3D

	if polygon and polygon.material_override and not Engine.is_editor_hint():
		polygon.material_override = polygon.material_override.duplicate()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		update_path()


func update_path() -> void:
	if road_path == null or origin == null or anchor == null:
		return

	var curve := road_path.curve

	if curve == null:
		curve = Curve3D.new()
		road_path.curve = curve

	curve.clear_points()

	var origin_pos := road_path.to_local(origin.global_position)
	var anchor_pos := road_path.to_local(anchor.global_position)

	var handle_len := origin_pos.distance_to(anchor_pos) / 3.0

	# Направление от Origin к Anchor
	var chord := (
		anchor.global_position - origin.global_position
	).normalized()

	var origin_dir := -origin.global_transform.basis.z
	var anchor_dir := -anchor.global_transform.basis.z

	# Origin должен смотреть в сторону Anchor
	if origin_dir.dot(chord) < 0.0:
		origin_dir = -origin_dir

	# Anchor тоже сначала ориентируем в сторону движения
	if anchor_dir.dot(chord) < 0.0:
		anchor_dir = -anchor_dir

	# Переводим направления из world space
	# в local space Path3D
	origin_dir = (
		road_path.global_transform.basis.inverse() * origin_dir
	).normalized()

	anchor_dir = (
		road_path.global_transform.basis.inverse() * anchor_dir
	).normalized()

	curve.add_point(
		origin_pos,
		Vector3.ZERO,
		origin_dir * handle_len
	)

	curve.add_point(
		anchor_pos,
		-anchor_dir * handle_len,
		Vector3.ZERO
	)


## Transform3D полотна дороги в ЛОКАЛЬНИХ координатах цього сегмента у
## точці t [0..1] вздовж нього (0 = Origin, 1 = Anchor). origin результату —
## точка на дорозі, basis.x — вектор "вбік" (перпендикулярно напрямку руху).
##
## Для поворотів (road_turn_left/right) читає реальну криву RoadPath —
## Origin/Anchor там лише точки стику з сусідами, а не сама траєкторія.
## Для прямих сегментів (немає RoadPath) рахує лінійно по Origin -> Anchor.

func road_transform_at(t: float) -> Transform3D:
	t = clampf(t, 0.0, 1.0)

	var road_path := get_node_or_null("RoadPath") as Path3D
	if road_path and road_path.curve and road_path.curve.get_baked_length() > 0.0:
		var curve := road_path.curve
		var offset := t * curve.get_baked_length()
		return road_path.transform * curve.sample_baked_with_rotation(offset)

	var o := origin.position
	var a := anchor.position
	var point := o.lerp(a, t)
	var dir := a - o
	var basis := Basis.IDENTITY
	if dir.length_squared() > 0.0001:
		basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	return Transform3D(basis, point)

func closest_t(local_point: Vector3) -> float:
	var road_path := get_node_or_null("RoadPath") as Path3D
	if road_path and road_path.curve and road_path.curve.get_baked_length() > 0.0:
		var curve := road_path.curve
		var curve_local: Vector3 = road_path.transform.affine_inverse() * local_point
		return curve.get_closest_offset(curve_local) / curve.get_baked_length()

	var o := origin.position
	var a := anchor.position
	var dir := a - o
	var len_sq := dir.length_squared()
	if len_sq <= 0.0001:
		return 0.0
	return clampf((local_point - o).dot(dir) / len_sq, 0.0, 1.0)
