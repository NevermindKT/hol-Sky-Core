extends RefCounted
class_name Road_spine

const COARSE_STRIDE := 8
const HASH_CELL := 64.0
const MAX_RING := 32
const REFINE_MARGIN := 2.0

var points: PackedVector3Array
var offsets: PackedFloat64Array
var coarse: PackedInt32Array = PackedInt32Array()

class Query:
	var cd := PackedFloat32Array()
	var cu := PackedFloat32Array()
	var hit_distance := 0.0
	var hit_offset := 0.0
	var hit_y := 0.0
	var smooth_y := 0.0
	var coarse_distance := 0.0
	var refine_d2 := 0.0
	var refine_offset := 0.0
	var refine_y := 0.0


var _hash: Dictionary = {}

var _fx: PackedFloat32Array = PackedFloat32Array()
var _fz: PackedFloat32Array = PackedFloat32Array()
var _fy: PackedFloat32Array = PackedFloat32Array()

var _cax: PackedFloat32Array = PackedFloat32Array()
var _caz: PackedFloat32Array = PackedFloat32Array()
var _cdx: PackedFloat32Array = PackedFloat32Array()
var _cdz: PackedFloat32Array = PackedFloat32Array()
var _cinv: PackedFloat32Array = PackedFloat32Array()
var _cdev: PackedFloat32Array = PackedFloat32Array()


func _init(p_points: PackedVector3Array, p_offsets: PackedFloat64Array) -> void:
	points = p_points
	offsets = p_offsets

	var count := points.size()
	_fx.resize(count)
	_fz.resize(count)
	_fy.resize(count)
	for i in count:
		_fx[i] = points[i].x
		_fz[i] = points[i].z
		_fy[i] = points[i].y

	var last := count - 1
	var i := 0
	while i < last:
		coarse.append(i)
		i += COARSE_STRIDE
	if last >= 0:
		coarse.append(last)

	var segments := maxi(coarse.size() - 1, 0)
	_cax.resize(segments)
	_caz.resize(segments)
	_cdx.resize(segments)
	_cdz.resize(segments)
	_cinv.resize(segments)
	_cdev.resize(segments)

	for k in segments:
		var a := points[coarse[k]]
		var b := points[coarse[k + 1]]
		var dx := b.x - a.x
		var dz := b.z - a.z
		var l2 := dx * dx + dz * dz
		_cax[k] = a.x
		_caz[k] = a.z
		_cdx[k] = dx
		_cdz[k] = dz
		_cinv[k] = 1.0 / l2 if l2 > 0.000001 else 0.0

		var deviation := 0.0
		for f in range(coarse[k] + 1, coarse[k + 1]):
			deviation = maxf(deviation, segment_distance(points[f].x, points[f].z, k))
		_cdev[k] = deviation + 0.001

		var min_x := floori(minf(a.x, b.x) / HASH_CELL)
		var max_x := floori(maxf(a.x, b.x) / HASH_CELL)
		var min_z := floori(minf(a.z, b.z) / HASH_CELL)
		var max_z := floori(maxf(a.z, b.z) / HASH_CELL)
		for cz in range(min_z, max_z + 1):
			for cx in range(min_x, max_x + 1):
				var cell := Vector2i(cx, cz)
				if _hash.has(cell):
					_hash[cell].append(k)
				else:
					_hash[cell] = PackedInt32Array([k])


func is_valid() -> bool:
	return coarse.size() >= 2


func start_offset() -> float:
	return offsets[0] if offsets.size() > 0 else 0.0


func end_offset() -> float:
	return offsets[offsets.size() - 1] if offsets.size() > 0 else 0.0


func sample_transform(offset: float) -> Transform3D:
	var n := points.size()
	if n == 0:
		return Transform3D.IDENTITY
	if n == 1:
		return Transform3D(Basis.IDENTITY, points[0])

	var i := clampi(offsets.bsearch(offset) - 1, 0, n - 2)
	var o0 := offsets[i]
	var o1 := offsets[i + 1]
	var f := clampf((offset - o0) / maxf(o1 - o0, 0.000001), 0.0, 1.0)
	var a := points[i]
	var b := points[i + 1]

	var forward := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	if forward == Vector3.ZERO:
		forward = Vector3.BACK
	var side := Vector3(forward.z, 0.0, -forward.x)

	return Transform3D(Basis(side, Vector3.UP, forward), a.lerp(b, f))


func segment_distance(x: float, z: float, k: int) -> float:
	var a := points[coarse[k]]
	var b := points[coarse[k + 1]]
	var dx := b.x - a.x
	var dz := b.z - a.z
	var l2 := dx * dx + dz * dz
	var u := 0.0
	if l2 > 0.000001:
		u = clampf(((x - a.x) * dx + (z - a.z) * dz) / l2, 0.0, 1.0)
	var qx := a.x + dx * u - x
	var qz := a.z + dz * u - z
	return sqrt(qx * qx + qz * qz)


func nearest_coarse_distance(x: float, z: float) -> float:
	if not is_valid():
		return INF

	var cx := floori(x / HASH_CELL)
	var cz := floori(z / HASH_CELL)
	var best := INF

	for r in range(MAX_RING + 1):
		if r == 0:
			best = _scan_cell(Vector2i(cx, cz), x, z, best)
		else:
			for dx in range(-r, r + 1):
				best = _scan_cell(Vector2i(cx + dx, cz - r), x, z, best)
				best = _scan_cell(Vector2i(cx + dx, cz + r), x, z, best)
			for dz in range(-r + 1, r):
				best = _scan_cell(Vector2i(cx - r, cz + dz), x, z, best)
				best = _scan_cell(Vector2i(cx + r, cz + dz), x, z, best)
		if best <= r * HASH_CELL:
			break

	return best


func gather(x: float, z: float, half_extent: float, extra: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	var upper := nearest_coarse_distance(x, z)
	if upper == INF:
		return result

	var radius := upper + 2.0 * half_extent + extra
	var min_x := floori((x - radius) / HASH_CELL)
	var max_x := floori((x + radius) / HASH_CELL)
	var min_z := floori((z - radius) / HASH_CELL)
	var max_z := floori((z + radius) / HASH_CELL)
	var seen := {}

	for cz in range(min_z, max_z + 1):
		for cx in range(min_x, max_x + 1):
			var cell := Vector2i(cx, cz)
			if not _hash.has(cell):
				continue
			for k in _hash[cell]:
				if seen.has(k):
					continue
				seen[k] = true
				if segment_distance(x, z, k) <= radius:
					result.append(k)

	result.sort()
	return result


func query(x: float, z: float, candidates: PackedInt32Array, blend_radius: float, q: Query) -> bool:
	var n := candidates.size()
	if n == 0:
		return false
	if q.cd.size() < n:
		q.cd.resize(n)
		q.cu.resize(n)

	var cd := q.cd
	var cu := q.cu
	var best := INF
	var best_c := 0

	for c in n:
		var k := candidates[c]
		var ax := _cax[k]
		var az := _caz[k]
		var dx := _cdx[k]
		var dz := _cdz[k]
		var u := clampf(((x - ax) * dx + (z - az) * dz) * _cinv[k], 0.0, 1.0)
		var qx := ax + dx * u - x
		var qz := az + dz * u - z
		var d := sqrt(qx * qx + qz * qz)
		cd[c] = d
		cu[c] = u
		if d < best:
			best = d
			best_c = c

	q.coarse_distance = best

	q.refine_d2 = INF
	_refine(candidates[best_c], x, z, q)
	for c in n:
		if c == best_c:
			continue
		var k := candidates[c]
		var reach := cd[c] - _cdev[k]
		if reach > 0.0 and reach * reach >= q.refine_d2:
			continue
		_refine(k, x, z, q)

	var weight_sum := 0.0
	var y_sum := 0.0
	var limit := best + blend_radius
	for c in n:
		var d: float = cd[c]
		if d >= limit:
			continue
		var k := candidates[c]
		var w := 1.0 - smoothstep(0.0, blend_radius, d - best)
		var ya := _fy[coarse[k]]
		y_sum += w * (ya + (_fy[coarse[k + 1]] - ya) * cu[c])
		weight_sum += w

	q.hit_distance = sqrt(q.refine_d2)
	q.hit_offset = q.refine_offset
	q.hit_y = q.refine_y
	q.smooth_y = y_sum / weight_sum if weight_sum > 0.0 else q.refine_y
	return true


func _refine(k: int, x: float, z: float, q: Query) -> void:
	var fx := _fx
	var fz := _fz
	var best := q.refine_d2
	var best_i := -1
	var best_u := 0.0

	for i in range(coarse[k], coarse[k + 1]):
		var ax := fx[i]
		var az := fz[i]
		var dx := fx[i + 1] - ax
		var dz := fz[i + 1] - az
		var l2 := dx * dx + dz * dz
		var u := 0.0
		if l2 > 0.000001:
			u = clampf(((x - ax) * dx + (z - az) * dz) / l2, 0.0, 1.0)
		var qx := ax + dx * u - x
		var qz := az + dz * u - z
		var d2 := qx * qx + qz * qz
		if d2 < best:
			best = d2
			best_i = i
			best_u = u

	if best_i < 0:
		return
	q.refine_d2 = best
	q.refine_offset = lerpf(offsets[best_i], offsets[best_i + 1], best_u)
	q.refine_y = lerpf(_fy[best_i], _fy[best_i + 1], best_u)


func _scan_cell(cell: Vector2i, x: float, z: float, best: float) -> float:
	if not _hash.has(cell):
		return best
	for k in _hash[cell]:
		var d := segment_distance(x, z, k)
		if d < best:
			best = d
	return best
