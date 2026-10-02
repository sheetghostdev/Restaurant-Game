class_name GridNav
extends RefCounted
## Grid pathfinding for customers and staff. Uses AStar2D over the restaurant
## grid with edges removed where walls stand, so pathing is deterministic,
## cheap, and always agrees with what players see. Paths are string-pulled so
## NPCs walk in natural straight lines instead of grid zigzags.

var grid: RestaurantGrid
var astar := AStar2D.new()
var _dirty := true
var _origin := Vector2i.ZERO
var _w := 1
var _h := 1

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAG := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


func _init(g: RestaurantGrid) -> void:
	grid = g


func mark_dirty() -> void:
	_dirty = true


func _id(c: Vector2i) -> int:
	return (c.x - _origin.x) + (c.y - _origin.y) * _w


func _valid(c: Vector2i) -> bool:
	return c.x >= _origin.x and c.y >= _origin.y and c.x < _origin.x + _w and c.y < _origin.y + _h


func rebuild() -> void:
	_dirty = false
	astar.clear()
	_origin = grid.lot.position
	_w = grid.lot.size.x
	_h = grid.lot.size.y

	for z in _h:
		for x in _w:
			var c := _origin + Vector2i(x, z)
			var id := _id(c)
			astar.add_point(id, Vector2(c.x + 0.5, c.y + 0.5))
			if not grid.walkable(c):
				astar.set_point_disabled(id, true)
	for z in _h:
		for x in _w:
			var c := _origin + Vector2i(x, z)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = c + d
				if _valid(n) and not grid.wall_between(c, n):
					astar.connect_points(_id(c), _id(n))
			for d in [Vector2i(1, 1), Vector2i(-1, 1)]:
				var n: Vector2i = c + d
				if not _valid(n):
					continue
				var a := Vector2i(n.x, c.y)
				var b := Vector2i(c.x, n.y)
				if not (grid.walkable(a) and grid.walkable(b)):
					continue
				if grid.wall_between(c, a) or grid.wall_between(a, n) or grid.wall_between(c, b) or grid.wall_between(b, n):
					continue
				astar.connect_points(_id(c), _id(n))


func _ensure() -> void:
	if _dirty:
		rebuild()


## Returns world-space waypoints (y = 0) from `from` to the centre of `to_cell`.
func find_path(from: Vector3, to_cell: Vector2i, smooth := true) -> Array[Vector3]:
	_ensure()
	var out: Array[Vector3] = []
	var fc := GameConst.world_to_cell(from)
	if not _valid(fc) or not _valid(to_cell):
		return out
	var fid := _id(fc)
	var tid := _id(to_cell)
	var f_dis := astar.is_point_disabled(fid)
	var t_dis := astar.is_point_disabled(tid)
	astar.set_point_disabled(fid, false)
	astar.set_point_disabled(tid, false)
	var pts := astar.get_point_path(fid, tid)
	astar.set_point_disabled(fid, f_dis)
	astar.set_point_disabled(tid, t_dis)
	if pts.is_empty():
		return out
	var raw: Array[Vector2] = []
	raw.push_back(Vector2(from.x, from.z))
	for i in range(1, pts.size()):
		raw.push_back(pts[i])
	if smooth and raw.size() > 2:
		raw = _string_pull(raw)
	for i in range(1, raw.size()):
		out.push_back(Vector3(raw[i].x, 0.0, raw[i].y))
	return out


func reachable(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	_ensure()
	if not _valid(from_cell) or not _valid(to_cell):
		return false
	var fid := _id(from_cell)
	var tid := _id(to_cell)
	var t_dis := astar.is_point_disabled(tid)
	var f_dis := astar.is_point_disabled(fid)
	astar.set_point_disabled(tid, false)
	astar.set_point_disabled(fid, false)
	var ok := not astar.get_id_path(fid, tid).is_empty()
	astar.set_point_disabled(tid, t_dis)
	astar.set_point_disabled(fid, f_dis)
	return ok


func _string_pull(pts: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = [pts[0]]
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not _line_clear(pts[i], pts[j]):
			j -= 1
		out.push_back(pts[j])
		i = j
	return out


func _line_clear(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps := int(ceil(dist / 0.2))
	var prev := Vector2i(floori(a.x), floori(a.y))
	# Keep a margin from obstacles by testing a slightly widened corridor.
	var perp := (b - a).normalized().orthogonal() * 0.28
	for s in range(1, steps + 1):
		var p := a.lerp(b, float(s) / steps)
		for off in [Vector2.ZERO, perp, -perp]:
			var q: Vector2 = p + off
			var c := Vector2i(floori(q.x), floori(q.y))
			if not grid.walkable(c):
				# allow the start/end cells themselves
				if c != Vector2i(floori(a.x), floori(a.y)) and c != Vector2i(floori(b.x), floori(b.y)):
					return false
		var cur := Vector2i(floori(p.x), floori(p.y))
		if cur != prev:
			if absi(cur.x - prev.x) + absi(cur.y - prev.y) > 1:
				var m1 := Vector2i(cur.x, prev.y)
				var m2 := Vector2i(prev.x, cur.y)
				if grid.wall_between(prev, m1) or grid.wall_between(m1, cur) or grid.wall_between(prev, m2) or grid.wall_between(m2, cur):
					return false
			elif grid.wall_between(prev, cur):
				return false
			prev = cur
	return true
