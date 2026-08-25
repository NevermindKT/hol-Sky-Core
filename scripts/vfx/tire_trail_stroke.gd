extends MeshInstance3D
class_name Tire_trail_stroke


@export var width := 0.35
@export var texture_tile_length := 1.0
@export var min_point_spacing := 0.08

var _points: Array[Vector3] = []
var _lengths: Array[float] = []
var _mesh_data := ArrayMesh.new()


func _ready() -> void:
	mesh = _mesh_data

	if material_override:
		material_override = material_override.duplicate()
		if material_override is BaseMaterial3D:
			(material_override as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED


func add_point(local_position: Vector3) -> void:
	if not _points.is_empty() and local_position.distance_to(_points[-1]) < min_point_spacing:
		return

	var prev_length := 0.0 if _lengths.is_empty() else _lengths[-1]
	var segment_length := 0.0 if _points.is_empty() else local_position.distance_to(_points[-1])

	_points.append(local_position)
	_lengths.append(prev_length + segment_length)

	_rebuild_mesh()


func point_count() -> int:
	return _points.size()


func _rebuild_mesh() -> void:
	if _points.size() < 2:
		return

	var lefts: Array[Vector3] = []
	var rights: Array[Vector3] = []
	var vs: Array[float] = []

	for i in _points.size():
		var point := _points[i]
		var direction: Vector3

		if i == 0:
			direction = (_points[i + 1] - _points[i]).normalized()
		elif i == _points.size() - 1:
			direction = (_points[i] - _points[i - 1]).normalized()
		else:
			direction = (_points[i + 1] - _points[i - 1]).normalized()

		var right := direction.cross(Vector3.UP).normalized() * (width * 0.5)

		lefts.append(point - right)
		rights.append(point + right)
		vs.append(_lengths[i] / texture_tile_length)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in _points.size() - 1:
		var l0 := lefts[i]
		var r0 := rights[i]
		var l1 := lefts[i + 1]
		var r1 := rights[i + 1]
		var v0 := vs[i]
		var v1 := vs[i + 1]

		st.set_uv(Vector2(0.0, v0)); st.add_vertex(l0)
		st.set_uv(Vector2(1.0, v0)); st.add_vertex(r0)
		st.set_uv(Vector2(0.0, v1)); st.add_vertex(l1)

		st.set_uv(Vector2(1.0, v0)); st.add_vertex(r0)
		st.set_uv(Vector2(1.0, v1)); st.add_vertex(r1)
		st.set_uv(Vector2(0.0, v1)); st.add_vertex(l1)

	st.generate_normals()

	_mesh_data.clear_surfaces()
	st.commit(_mesh_data)
