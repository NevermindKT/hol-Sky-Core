@tool
extends Node3D
class_name LightningBolt

@export var regenerate := false:
	set(value):
		if value:
			_generate()
		regenerate = false

@export var height: float = 25.0
@export var horizontal_spread: float = 2.0
@export var width: float = 0.08
@export_range(0.3, 0.9, 0.05)
var roughness := 0.5

@export var branch_length := 0.4
@export var min_branches := 2
@export var max_branches := 5


func _ready():
	_generate()
	
func strike(position: Vector3) -> void:
	global_position = position
	_generate()
	
func show_bolt():
	visible = true
	
func hide_bolt():
	visible = false
	
func _generate():
	var ribbons: Array[PackedVector3Array]
	var main := generate_points()
	ribbons.append(main)

	add_branches(
		main,
		ribbons
	)

	var mesh_instance := get_node("MeshInstance3D")
	mesh_instance.mesh = build_ribbon_mesh(ribbons)
	
	
func add_branches(
	parent: PackedVector3Array,
	ribbons: Array[PackedVector3Array]
) -> void:

	if parent.size() < 8:
		return

	var branch_count := randi_range(
		min_branches,
		min(max_branches, parent.size() / 6)
	)

	var used_indices: Array[int] = []
	var min_gap := 6

	while used_indices.size() < branch_count:

		var index := randi_range(
			1,
			parent.size() - 3
		)

		var valid := true

		for used in used_indices:
			if abs(index - used) < min_gap:
				valid = false
				break

		if !valid:
			continue

		used_indices.append(index)

		ribbons.append(
			generate_branch(parent, index)
		)

func generate_branch(
	parent: PackedVector3Array,
	index: int
) -> PackedVector3Array:

	var points := PackedVector3Array()

	var start := parent[index]

	var direction := (
		parent[index + 1] -
		parent[index]
	).normalized()

	var side := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-0.3, 0.3),
		randf_range(-1.0, 1.0)
	).normalized()

	var end := start + (direction + side).normalized() * branch_length

	points.append(start)

	subdivide(
		points,
		start,
		end,
		horizontal_spread * 0.25
	)

	return points

func generate_points() -> PackedVector3Array:
	var points := PackedVector3Array()

	var start := Vector3(0.0, height, 0.0)
	var end := Vector3(0.0, 0.0, 0.0)

	points.append(start)
	subdivide(points, start, end, horizontal_spread)

	return points
	

func subdivide(
	points: PackedVector3Array,
	start: Vector3,
	end: Vector3,
	offset: float
) -> void:

	if offset < 0.1:
		points.append(end)
		return

	var middle := (start + end) * 0.5

	var random_offset := Vector3(
		randf_range(-offset, offset),
		0.0,
		randf_range(-offset, offset)
	)

	middle += random_offset

	var next_offset := offset * randf_range(
		max(0.1, roughness - 0.1),
		min(0.95, roughness + 0.1)
	)

	subdivide(points, start, middle, next_offset)
	subdivide(points, middle, end, next_offset)
	
func build_ribbon(
	points: PackedVector3Array,
	ribbon_width: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var half := ribbon_width * 0.5
	var vertex_offset := vertices.size()

	for i in range(points.size()):

		var point := points[i]

		var direction: Vector3

		if i == 0:
			direction = (points[1] - points[0]).normalized()

		elif i == points.size() - 1:
			direction = (points[i] - points[i - 1]).normalized()

		else:
			direction = (points[i + 1] - points[i - 1]).normalized()

		var to_camera = (
			camera.global_position - point
		).normalized()

		var right = to_camera.cross(direction).normalized()

		var left_vertex = point - right * half
		var right_vertex = point + right * half

		vertices.append(left_vertex)
		vertices.append(right_vertex)

		normals.append(-to_camera)
		normals.append(-to_camera)

		var t = float(i) / float(points.size() - 1)

		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))

	for i in range(points.size() - 1):

		var base = vertex_offset + i * 2

		indices.append_array([
			base,
			base + 1,
			base + 2,

			base + 1,
			base + 3,
			base + 2
		])

func build_ribbon_mesh(ribbons: Array[PackedVector3Array]) -> ArrayMesh:

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for ribbon in ribbons:
		build_ribbon(
			ribbon,
			width,
			vertices,
			normals,
			uvs,
			indices
		)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()

	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)

	return mesh
