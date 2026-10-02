class_name MeshBuilder
extends RefCounted
## Procedural low-poly geometry with a "miniature model kit" look.
##
## Everything is flat shaded with per-vertex colour. Primitives support chamfered
## (bevelled) edges, which catch light like the edges of a painted model piece,
## and an optional deterministic "handmade" jitter. On commit, a cheap baked
## ambient-occlusion pass darkens low and downward-facing geometry.
##
## Coordinates passed to primitives are in the builder's current local space
## (see push()/pop()), so complex models can be composed hierarchically.

## Set to true if triangles must be emitted in the reverse order for the
## renderer's front-face convention.
const FLIP_WINDING := true

var ao_strength := 0.22
var down_shade := 0.68
var contact_shade := 0.12
var jitter := 0.0

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _cols := PackedColorArray()
var _xf := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []


func push(t: Transform3D) -> MeshBuilder:
	_stack.push_back(_xf)
	_xf = _xf * t
	return self


func push_at(pos: Vector3, yaw := 0.0, scl := Vector3.ONE, pitch := 0.0, roll := 0.0) -> MeshBuilder:
	var b := Basis.from_euler(Vector3(pitch, yaw, roll)).scaled(scl)
	return push(Transform3D(b, pos))


func pop() -> MeshBuilder:
	if not _stack.is_empty():
		_xf = _stack.pop_back()
	return self


func is_empty() -> bool:
	return _verts.is_empty()


# -----------------------------------------------------------------------------
# Low level
# -----------------------------------------------------------------------------

func _j(p: Vector3) -> Vector3:
	if jitter <= 0.0:
		return p
	# Deterministic hash of the position so shared corners move together.
	var h := int(p.x * 7919.0) * 73856093 ^ int(p.y * 7919.0) * 19349663 ^ int(p.z * 7919.0) * 83492791
	var r := RandomNumberGenerator.new()
	r.seed = h
	return p + Vector3(r.randf_range(-1, 1), r.randf_range(-1, 1), r.randf_range(-1, 1)) * jitter


## Adds a convex polygon (fan triangulated). `outward` is a local-space hint used
## to orient the face; pass Vector3.ZERO to trust the given winding.
func face(points: PackedVector3Array, color: Color, outward := Vector3.ZERO) -> void:
	if points.size() < 3:
		return
	var p := PackedVector3Array()
	p.resize(points.size())
	for i in points.size():
		p[i] = _xf * _j(points[i])
	var n := _poly_normal(p)
	if n == Vector3.ZERO:
		return
	if outward != Vector3.ZERO:
		var ow := (_xf.basis * outward)
		if n.dot(ow) < 0.0:
			p.reverse()
			n = -n
	for i in range(1, p.size() - 1):
		if FLIP_WINDING:
			_emit(p[0], n, color)
			_emit(p[i + 1], n, color)
			_emit(p[i], n, color)
		else:
			_emit(p[0], n, color)
			_emit(p[i], n, color)
			_emit(p[i + 1], n, color)


func _poly_normal(p: PackedVector3Array) -> Vector3:
	# Newell's method: robust for slightly non-planar quads.
	var n := Vector3.ZERO
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		n.x += (a.y - b.y) * (a.z + b.z)
		n.y += (a.z - b.z) * (a.x + b.x)
		n.z += (a.x - b.x) * (a.y + b.y)
	if n.length_squared() < 1e-12:
		return Vector3.ZERO
	return n.normalized()


func _emit(v: Vector3, n: Vector3, c: Color) -> void:
	_verts.push_back(v)
	_norms.push_back(n)
	_cols.push_back(c)


func _face_auto(points: PackedVector3Array, color: Color, center: Vector3) -> void:
	var cen := Vector3.ZERO
	for q in points:
		cen += q
	cen /= points.size()
	face(points, color, cen - center)


# -----------------------------------------------------------------------------
# Primitives
# -----------------------------------------------------------------------------

## Axis aligned box centred on `c`. `bevel` chamfers every edge. `top` (if its
## alpha > 0) colours the top face and top chamfers.
func box(c: Vector3, s: Vector3, col: Color, bevel := 0.0, top := Color(0, 0, 0, 0)) -> void:
	var h := s * 0.5
	var tc := top if top.a > 0.0 else col
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
	if b <= 0.0005:
		_face_auto(PackedVector3Array([c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(h.x, -h.y, h.z)]), col, c)
		_face_auto(PackedVector3Array([c + Vector3(-h.x, -h.y, -h.z), c + Vector3(-h.x, h.y, -h.z), c + Vector3(-h.x, h.y, h.z), c + Vector3(-h.x, -h.y, h.z)]), col, c)
		_face_auto(PackedVector3Array([c + Vector3(-h.x, h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z)]), tc, c)
		_face_auto(PackedVector3Array([c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(-h.x, -h.y, h.z)]), col, c)
		_face_auto(PackedVector3Array([c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z)]), col, c)
		_face_auto(PackedVector3Array([c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z)]), col, c)
		return
	var i := h - Vector3(b, b, b)
	# Six main faces.
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var pts := PackedVector3Array()
			for k in 4:
				var u := -1.0 if (k == 0 or k == 3) else 1.0
				var v := -1.0 if (k < 2) else 1.0
				var p := Vector3.ZERO
				p[axis] = sgn * h[axis]
				p[(axis + 1) % 3] = u * i[(axis + 1) % 3]
				p[(axis + 2) % 3] = v * i[(axis + 2) % 3]
				pts.push_back(c + p)
			var fc := tc if (axis == 1 and sgn > 0.0) else col
			_face_auto(pts, fc, c)
	# Twelve edge chamfers.
	for a1 in 3:
		for a2 in range(a1 + 1, 3):
			var a3 := 3 - a1 - a2
			for s1 in [-1.0, 1.0]:
				for s2 in [-1.0, 1.0]:
					var pts := PackedVector3Array()
					for e in [-1.0, 1.0]:
						var pa := Vector3.ZERO
						pa[a1] = s1 * h[a1]
						pa[a2] = s2 * i[a2]
						pa[a3] = e * i[a3]
						var pb := Vector3.ZERO
						pb[a1] = s1 * i[a1]
						pb[a2] = s2 * h[a2]
						pb[a3] = e * i[a3]
						pts.push_back(c + pa)
						pts.push_back(c + pb)
					# reorder to a proper quad loop: pa(-), pb(-), pb(+), pa(+)
					var quad := PackedVector3Array([pts[0], pts[1], pts[3], pts[2]])
					var is_top: bool = (a1 == 1 and s1 > 0.0) or (a2 == 1 and s2 > 0.0)
					_face_auto(quad, tc if is_top else col, c)
	# Eight corner triangles.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var tri := PackedVector3Array([
					c + Vector3(sx * h.x, sy * i.y, sz * i.z),
					c + Vector3(sx * i.x, sy * h.y, sz * i.z),
					c + Vector3(sx * i.x, sy * i.y, sz * h.z),
				])
				_face_auto(tri, tc if sy > 0.0 else col, c)


## Box resting on `base` (base is the centre of its bottom face).
func block(base: Vector3, s: Vector3, col: Color, bevel := 0.0, top := Color(0, 0, 0, 0)) -> void:
	box(base + Vector3(0, s.y * 0.5, 0), s, col, bevel, top)


## Vertical prism / frustum standing on `base`. `sides` low values (5-10) keep the
## angular, handmade look. `r_top < 0` means same as bottom radius.
func cyl(base: Vector3, r: float, h: float, col: Color, sides := 8, bevel := 0.0, top := Color(0, 0, 0, 0), r_top := -1.0, angle_offset := 0.0) -> void:
	var rt := r if r_top < 0.0 else r_top
	var tc := top if top.a > 0.0 else col
	var center := base + Vector3(0, h * 0.5, 0)
	var b := minf(bevel, minf(h * 0.45, minf(r, maxf(rt, 0.001)) * 0.6))
	var rings: Array = []  # [radius, y, color]
	if b > 0.0005:
		rings = [[r - b, 0.0], [r, b], [rt, h - b], [rt - b if rt > b else 0.0, h]]
	else:
		rings = [[r, 0.0], [rt, h]]
	var ang := TAU / float(sides)
	var ring_pts: Array = []
	for rg in rings:
		var arr := PackedVector3Array()
		for k in sides:
			var a := angle_offset + ang * k
			arr.push_back(base + Vector3(cos(a) * rg[0], rg[1], sin(a) * rg[0]))
		ring_pts.push_back(arr)
	# Side bands.
	for ri in ring_pts.size() - 1:
		var lo: PackedVector3Array = ring_pts[ri]
		var hi: PackedVector3Array = ring_pts[ri + 1]
		var band_col := col
		if ri == ring_pts.size() - 2 and b > 0.0005:
			band_col = tc
		for k in sides:
			var k2 := (k + 1) % sides
			var q := PackedVector3Array([lo[k], lo[k2], hi[k2], hi[k]])
			if hi[k].distance_to(hi[k2]) < 1e-5:
				q = PackedVector3Array([lo[k], lo[k2], hi[k]])
			_face_auto(q, band_col, center)
	# Caps.
	var bottom: PackedVector3Array = ring_pts[0]
	var topr: PackedVector3Array = ring_pts[ring_pts.size() - 1]
	face(bottom, col, Vector3.DOWN)
	if topr[0].distance_to(topr[1]) > 1e-5:
		face(topr, tc, Vector3.UP)


## Low-poly ellipsoid built from a subdivided icosahedron.
func sphere(c: Vector3, radius: Vector3, col: Color, detail := 1, top := Color(0, 0, 0, 0), wobble := 0.0, seed_value := 0) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for k in v.size():
		v[k] = v[k].normalized()
	var f: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	for _d in detail:
		var nf: Array = []
		var cache := {}
		for tri in f:
			var m: Array[int] = []
			for e in 3:
				var a: int = tri[e]
				var b2: int = tri[(e + 1) % 3]
				var key := Vector2i(mini(a, b2), maxi(a, b2))
				if not cache.has(key):
					v.push_back(((v[a] + v[b2]) * 0.5).normalized())
					cache[key] = v.size() - 1
				m.push_back(cache[key])
			nf.push_back([tri[0], m[0], m[2]])
			nf.push_back([tri[1], m[1], m[0]])
			nf.push_back([tri[2], m[2], m[1]])
			nf.push_back([m[0], m[1], m[2]])
		f = nf
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts: Array[Vector3] = []
	for p in v:
		var w := 1.0 + (rng.randf_range(-wobble, wobble) if wobble > 0.0 else 0.0)
		pts.push_back(c + Vector3(p.x * radius.x, p.y * radius.y, p.z * radius.z) * w)
	var tc := top if top.a > 0.0 else col
	for tri in f:
		var a: Vector3 = pts[tri[0]]
		var b3: Vector3 = pts[tri[1]]
		var d: Vector3 = pts[tri[2]]
		var cen := (a + b3 + d) / 3.0
		var fc := tc if (cen.y - c.y) > radius.y * 0.35 else col
		face(PackedVector3Array([a, b3, d]), fc, cen - c)


## Extrudes a 2D polygon (XZ plane) between y0 and y1. Handles concave shapes.
func extrude(poly: PackedVector2Array, y0: float, y1: float, col: Color, top := Color(0, 0, 0, 0)) -> void:
	var tc := top if top.a > 0.0 else col
	var idx := Geometry2D.triangulate_polygon(poly)
	var cen := Vector2.ZERO
	for p in poly:
		cen += p
	cen /= poly.size()
	for k in range(0, idx.size(), 3):
		var a := poly[idx[k]]
		var b := poly[idx[k + 1]]
		var d := poly[idx[k + 2]]
		face(PackedVector3Array([Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(d.x, y1, d.y)]), tc, Vector3.UP)
		face(PackedVector3Array([Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(d.x, y0, d.y)]), col, Vector3.DOWN)
	# Orientation of the outline decides the outward side.
	var area := 0.0
	for k in poly.size():
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		area += p.x * q.y - q.x * p.y
	for k in poly.size():
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		var edge := q - p
		var out2 := Vector2(edge.y, -edge.x) if area > 0.0 else Vector2(-edge.y, edge.x)
		face(PackedVector3Array([Vector3(p.x, y0, p.y), Vector3(q.x, y0, q.y), Vector3(q.x, y1, q.y), Vector3(p.x, y1, p.y)]), col, Vector3(out2.x, 0, out2.y))


## Flat, slightly wavy leaf/disc (lettuce, cheese drips, splats).
func wavy_disc(c: Vector3, r: float, thickness: float, col: Color, lobes := 7, wave := 0.25, lift := 0.03, seed_value := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := lobes * 2
	var top := PackedVector3Array()
	var bot := PackedVector3Array()
	for k in n:
		var a := TAU * k / n
		var rr := r * (1.0 + (wave if k % 2 == 0 else -wave * 0.4)) * rng.randf_range(0.92, 1.08)
		var y := lift * (1.0 if k % 2 == 0 else -0.5)
		top.push_back(c + Vector3(cos(a) * rr, thickness + y, sin(a) * rr))
		bot.push_back(c + Vector3(cos(a) * rr, y, sin(a) * rr))
	var tc := c + Vector3(0, thickness + lift * 0.3, 0)
	for k in n:
		var k2 := (k + 1) % n
		face(PackedVector3Array([tc, top[k], top[k2]]), col, Vector3.UP)
		face(PackedVector3Array([c, bot[k2], bot[k]]), col.darkened(0.15), Vector3.DOWN)
		face(PackedVector3Array([bot[k], bot[k2], top[k2], top[k]]), col.darkened(0.05), (top[k] + top[k2]) * 0.5 - tc)


## Thin flat quad on the ground (decals, markings) at height y.
func flat(rect_min: Vector2, rect_max: Vector2, y: float, col: Color) -> void:
	face(PackedVector3Array([
		Vector3(rect_min.x, y, rect_min.y), Vector3(rect_max.x, y, rect_min.y),
		Vector3(rect_max.x, y, rect_max.y), Vector3(rect_min.x, y, rect_max.y),
	]), col, Vector3.UP)


# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------

func _bake_colors() -> PackedColorArray:
	var out := _cols.duplicate()
	if _verts.is_empty():
		return out
	var ymin := INF
	var ymax := -INF
	for v in _verts:
		ymin = minf(ymin, v.y)
		ymax = maxf(ymax, v.y)
	var span := maxf(ymax - ymin, 0.001)
	for k in _verts.size():
		var t := clampf((_verts[k].y - ymin) / span, 0.0, 1.0)
		var f := lerpf(1.0 - ao_strength, 1.0, sqrt(t))
		if _verts[k].y - ymin < 0.04:
			f *= 1.0 - contact_shade
		var ny := _norms[k].y
		if ny < -0.2:
			f *= lerpf(1.0, down_shade, clampf(-ny, 0.0, 1.0))
		var c := out[k]
		out[k] = Color(c.r, c.g, c.b, clampf(f, 0.0, 1.0))
	return out


func commit(material: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	commit_to(mesh, material)
	return mesh


func commit_to(mesh: ArrayMesh, material: Material = null) -> void:
	if _verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_COLOR] = _bake_colors()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)


func clear() -> void:
	_verts.clear()
	_norms.clear()
	_cols.clear()
	_xf = Transform3D.IDENTITY
	_stack.clear()
