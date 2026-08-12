extends Node3D
class_name Road_segment

@export var anchor: Marker3D
@export var origin: Marker3D

@export var weight := 1.0
@export var segment_type: RoadType.Type

var polygon: CSGPolygon3D

var length: float

func _ready() -> void:
	assert(origin != null, "Origin missing in " + name)
	assert(anchor != null, "Anchor missing in " + name)
	length = origin.position.distance_to(anchor.position)


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


## Найближчий до заданої точки (в ЛОКАЛЬНИХ координатах цього сегмента)
## параметр t [0..1] вздовж полотна дороги.
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
