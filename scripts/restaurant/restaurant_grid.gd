class_name RestaurantGrid
extends Node
## The building as data: rooms on a 1 m grid, openings between cells, fixture
## occupancy and walkability. Walls are derived (any edge between two different
## rooms, or a room and the outside, is a wall unless it is an opening).
##
## The same dictionary format is used by starting layouts (data/layouts/*.json)
## and by save files, so a restaurant is always fully described by data.

signal layout_changed
signal occupancy_changed

const OPEN_TYPES := ["door", "front", "roller", "arch", "swing", "train_door", "airlock"]

var lot := Rect2i(-4, -8, 34, 24)
var rooms: Array[Dictionary] = []          ## {id, type, rect: Rect2i}
var openings := {}                         ## Vector4i edge -> String type
var front_door := Vector4i.ZERO            ## inside cell (x,z) -> outside cell
var delivery_zone: Array[Vector2i] = []
var street := {}                           ## spawn/exit/queue points
var built_expansions: Array[StringName] = []
var locked := {}                           ## opening type -> true while those doors are shut (train doors between stops)

var _cell_room := {}                       ## Vector2i -> room index
var _fixtures := {}                        ## Vector2i -> Fixture
var nav: GridNav


func _init() -> void:
	nav = GridNav.new(self)


# -----------------------------------------------------------------------------
# Layout data
# -----------------------------------------------------------------------------

func load_layout(d: Dictionary) -> void:
	rooms.clear()
	openings.clear()
	delivery_zone.clear()
	built_expansions.clear()
	if d.has("lot"):
		var l: Array = d["lot"]
		lot = Rect2i(l[0], l[1], l[2], l[3])
	for r in d.get("rooms", []):
		var rr: Array = r["rect"]
		rooms.push_back({"id": StringName(r["id"]), "type": StringName(r["type"]), "rect": Rect2i(rr[0], rr[1], rr[2], rr[3])})
	for o in d.get("openings", []):
		openings[edge_key(Vector2i(o[0], o[1]), Vector2i(o[2], o[3]))] = String(o[4]) if o.size() > 4 else "door"
	if d.has("front_door"):
		var f: Array = d["front_door"]
		front_door = Vector4i(f[0], f[1], f[2], f[3])
		openings[edge_key(Vector2i(f[0], f[1]), Vector2i(f[2], f[3]))] = "front"
	for c in d.get("delivery_zone", []):
		delivery_zone.push_back(Vector2i(c[0], c[1]))
	street = d.get("street", {})
	for e in d.get("built_expansions", []):
		built_expansions.push_back(StringName(e))
	_rebuild_index()
	layout_changed.emit()


func save_layout() -> Dictionary:
	var rs := []
	for r in rooms:
		var rect: Rect2i = r["rect"]
		rs.push_back({"id": String(r["id"]), "type": String(r["type"]), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	var os := []
	for k in openings:
		var e: Vector4i = k
		if e == edge_key(Vector2i(front_door.x, front_door.y), Vector2i(front_door.z, front_door.w)):
			continue
		os.push_back([e.x, e.y, e.z, e.w, openings[k]])
	var dz := []
	for c in delivery_zone:
		dz.push_back([c.x, c.y])
	var ex := []
	for e in built_expansions:
		ex.push_back(String(e))
	return {
		"lot": [lot.position.x, lot.position.y, lot.size.x, lot.size.y],
		"rooms": rs,
		"openings": os,
		"front_door": [front_door.x, front_door.y, front_door.z, front_door.w],
		"delivery_zone": dz,
		"street": street,
		"built_expansions": ex,
	}


## Shuts (or opens) every opening of `type`, e.g. the train's platform doors.
func set_locked(type: String, on: bool) -> void:
	if locked.has(type) == on:
		return
	if on:
		locked[type] = true
	else:
		locked.erase(type)
	nav.mark_dirty()


func add_room(id: StringName, type: StringName, rect: Rect2i) -> void:
	rooms.push_back({"id": id, "type": type, "rect": rect})
	_rebuild_index()
	layout_changed.emit()


func set_opening(a: Vector2i, b: Vector2i, type: String) -> void:
	if type == "":
		openings.erase(edge_key(a, b))
	else:
		openings[edge_key(a, b)] = type
	nav.mark_dirty()
	layout_changed.emit()


func _rebuild_index() -> void:
	_cell_room.clear()
	for i in rooms.size():
		var r: Rect2i = rooms[i]["rect"]
		for x in range(r.position.x, r.end.x):
			for z in range(r.position.y, r.end.y):
				_cell_room[Vector2i(x, z)] = i
	nav.mark_dirty()


static func edge_key(a: Vector2i, b: Vector2i) -> Vector4i:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return Vector4i(a.x, a.y, b.x, b.y)
	return Vector4i(b.x, b.y, a.x, a.y)


# -----------------------------------------------------------------------------
# Queries
# -----------------------------------------------------------------------------

func room_index(c: Vector2i) -> int:
	return _cell_room.get(c, -1)


func room_at(c: Vector2i) -> Dictionary:
	var i := room_index(c)
	return rooms[i] if i >= 0 else {}


func room_type_at(c: Vector2i) -> RoomTypeDef:
	var r := room_at(c)
	if r.is_empty():
		return null
	return Content.room_type(r["type"])


func is_inside(c: Vector2i) -> bool:
	var rt := room_type_at(c)
	return rt != null and not rt.outdoor


func is_building(c: Vector2i) -> bool:
	return room_index(c) >= 0


func is_cold_cell(c: Vector2i) -> bool:
	var rt := room_type_at(c)
	return rt != null and rt.cold


func is_customer_area(c: Vector2i) -> bool:
	var rt := room_type_at(c)
	return rt != null and rt.customer_area


func in_lot(c: Vector2i) -> bool:
	return lot.has_point(c)


func opening_type(a: Vector2i, b: Vector2i) -> String:
	return openings.get(edge_key(a, b), "")


## True if there is a wall (or fence) between two orthogonally adjacent cells.
func wall_between(a: Vector2i, b: Vector2i) -> bool:
	var ra := room_index(a)
	var rb := room_index(b)
	if ra == rb:
		return false
	var op: String = openings.get(edge_key(a, b), "")
	if op != "":
		return locked.has(op)
	var ta := room_type_at(a)
	var tb := room_type_at(b)
	var a_out := ta == null or ta.outdoor
	var b_out := tb == null or tb.outdoor
	if a_out and b_out:
		# Outdoor service areas (patio) are fenced off from the street; work
		# areas (loading dock) are open to the alley.
		return fence_between(a, b)
	return true


## True where an outdoor customer area meets the open street (picket fence).
func fence_between(a: Vector2i, b: Vector2i) -> bool:
	if openings.has(edge_key(a, b)):
		return false
	var ta := room_type_at(a)
	var tb := room_type_at(b)
	if ta != null and tb != null:
		return false
	var inner := ta if ta != null else tb
	return inner != null and inner.outdoor and inner.customer_area


## True if the straight line from `a` to `b` (world positions) crosses a wall
## or fence. Used so nobody can reach through a wall to a counter behind it.
func line_crosses_wall(a: Vector3, b: Vector3) -> bool:
	var from := Vector2(a.x, a.z)
	var to := Vector2(b.x, b.z)
	var steps := maxi(1, int(ceil(from.distance_to(to) / 0.1)))
	var prev := Vector2i(floori(from.x), floori(from.y))
	for i in range(1, steps + 1):
		var q := from.lerp(to, float(i) / steps)
		var c := Vector2i(floori(q.x), floori(q.y))
		if c == prev:
			continue
		if c.x != prev.x and c.y != prev.y:
			# Diagonal step past a corner: blocked only if both ways round are.
			var via_x := Vector2i(c.x, prev.y)
			var via_z := Vector2i(prev.x, c.y)
			if (wall_between(prev, via_x) or wall_between(via_x, c)) and (wall_between(prev, via_z) or wall_between(via_z, c)):
				return true
		elif wall_between(prev, c):
			return true
		prev = c
	return false


func fixture_at(c: Vector2i) -> Fixture:
	var f = _fixtures.get(c)
	if f != null and not is_instance_valid(f):
		_fixtures.erase(c)
		return null
	return f


func occupy(f: Fixture) -> void:
	_fixtures[f.cell] = f
	nav.mark_dirty()
	occupancy_changed.emit()


func vacate(f: Fixture) -> void:
	if _fixtures.get(f.cell) == f:
		_fixtures.erase(f.cell)
	nav.mark_dirty()
	occupancy_changed.emit()


func all_fixtures() -> Array:
	var out := []
	for f in _fixtures.values():
		if is_instance_valid(f):
			out.push_back(f)
	return out


func fixtures_of(def_id: StringName) -> Array:
	var out := []
	for f in all_fixtures():
		if f.def_id == def_id:
			out.push_back(f)
	return out


## Cells a fixture could be placed on.
func can_place(c: Vector2i, def: FixtureDef, ignore: Fixture = null) -> bool:
	if not is_building(c):
		return false
	var rt := room_type_at(c)
	if rt and rt.outdoor and not (def and def.allowed_outdoors):
		return false
	var f := fixture_at(c)
	if f and f != ignore:
		return false
	# Never block a doorway completely.
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = c + d
		if openings.has(edge_key(c, n)) and def and def.blocks_movement:
			return false
	if c in delivery_zone:
		return false
	return true


func walkable(c: Vector2i) -> bool:
	if not in_lot(c):
		return false
	var f := fixture_at(c)
	if f and f.def and f.def.blocks_movement and not f.lifted:
		return false
	return true


func building_bounds() -> Rect2i:
	if rooms.is_empty():
		return Rect2i(0, 0, 10, 10)
	var r: Rect2i = rooms[0]["rect"]
	for i in range(1, rooms.size()):
		r = r.merge(rooms[i]["rect"])
	return r


func cells_of_type(type: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in rooms:
		if r["type"] != type:
			continue
		var rect: Rect2i = r["rect"]
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				out.push_back(Vector2i(x, z))
	return out


func street_point(key: String, fallback := Vector2i.ZERO) -> Vector2i:
	var a = street.get(key)
	if a is Array and a.size() >= 2:
		return Vector2i(int(a[0]), int(a[1]))
	return fallback
