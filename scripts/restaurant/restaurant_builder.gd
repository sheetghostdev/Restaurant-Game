class_name RestaurantBuilder
extends Node3D
## Turns RestaurantGrid data into a miniature cutaway building: a display
## plinth, street, floors per room style, walls cut open toward the camera,
## windows, door frames, interior lights and street props.
##
## Walls running along X whose south side faces the camera are built low
## (cut) so interiors stay readable; back walls and side walls are full height
## with a dark "section cut" cap, like an architectural model.

const WALL_T := 0.2
const WALL_TALL := 2.5
const WALL_LOW := 0.5
const FLOOR_Y := 0.0
const GROUND_Y := -0.04

var grid: RestaurantGrid
var _static: Node3D
var _body: StaticBody3D
var _lights: Node3D
var _doors: Node3D
var _props: Node3D
var room_lights: Array[OmniLight3D] = []
var power_dim := 0.0          ## 1 = power cut (interior lights flicker low)
var window_glass: Array[MeshInstance3D] = []
var swing_doors: Array[Node3D] = []
var _layout_props: Array = []
var _ground_rects: Array = []


func setup(g: RestaurantGrid, layout: Dictionary) -> void:
	grid = g
	_layout_props = layout.get("props", [])
	_ground_rects = layout.get("ground", [])


func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	room_lights.clear()
	window_glass.clear()
	swing_doors.clear()
	_static = Node3D.new()
	_static.name = "Static"
	add_child(_static)
	_body = StaticBody3D.new()
	_body.name = "WallCollision"
	_body.collision_layer = GameConst.L_WORLD
	_body.collision_mask = 0
	add_child(_body)
	_lights = Node3D.new()
	_lights.name = "RoomLights"
	add_child(_lights)
	_doors = Node3D.new()
	_doors.name = "Doors"
	add_child(_doors)
	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)
	_build_plinth_and_ground()
	_build_floors()
	_build_walls()
	_build_lights()
	_build_props()
	_build_bounds()


func _mi(mesh: Mesh, parent: Node3D = null, cast_shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else _static).add_child(mi)
	return mi


# -----------------------------------------------------------------------------
# Plinth, ground and street
# -----------------------------------------------------------------------------

func _build_plinth_and_ground() -> void:
	var b := MeshBuilder.new()
	b.ao_strength = 0.0
	b.contact_shade = 0.0
	var lot := grid.lot
	var margin := 0.6
	var x0 := lot.position.x - margin
	var z0 := lot.position.y - margin
	var x1 := lot.end.x + margin
	var z1 := lot.end.y + margin
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	# Display plinth: dark wood with a lighter trim line, like a model base.
	b.box(Vector3(cx, -0.45, cz), Vector3(x1 - x0, 0.8, z1 - z0), Pal.PLINTH, 0.06)
	b.box(Vector3(cx, -0.12, cz), Vector3(x1 - x0 + 0.04, 0.05, z1 - z0 + 0.04), Pal.PLINTH.lightened(0.25), 0.015)
	# Ground (grass) top
	b.box(Vector3(lot.get_center().x, GROUND_Y - 0.05, lot.get_center().y), Vector3(lot.size.x, 0.1, lot.size.y), Pal.GRASS, 0.02)
	# Ground details from the layout (sidewalks, roads, lots)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for g in _ground_rects:
		var r: Array = g["rect"]
		var rect := Rect2(r[0], r[1], r[2], r[3])
		match String(g["type"]):
			"sidewalk":
				for x in range(int(rect.position.x), int(rect.end.x)):
					for z in range(int(rect.position.y), int(rect.end.y)):
						var c := Pal.SIDEWALK.darkened(rng.randf() * 0.04)
						b.box(Vector3(x + 0.5, GROUND_Y + 0.01, z + 0.5), Vector3(0.96, 0.06, 0.96), c, 0.015)
			"road":
				b.box(Vector3(rect.get_center().x, GROUND_Y - 0.03, rect.get_center().y), Vector3(rect.size.x, 0.04, rect.size.y), Pal.ASPHALT)
				if rect.size.x > rect.size.y:
					var mid := rect.get_center().y
					var x := rect.position.x + 0.5
					while x < rect.end.x - 0.5:
						b.box(Vector3(x + 0.4, GROUND_Y - 0.005, mid), Vector3(0.8, 0.01, 0.12), Pal.ROAD_LINE)
						x += 1.8
					b.box(Vector3(rect.get_center().x, GROUND_Y + 0.0, rect.position.y + 0.06), Vector3(rect.size.x, 0.08, 0.12), Pal.CURB)
				else:
					var midx := rect.get_center().x
					var z := rect.position.y + 0.5
					while z < rect.end.y - 0.5:
						b.box(Vector3(midx, GROUND_Y - 0.005, z + 0.4), Vector3(0.12, 0.01, 0.8), Pal.ROAD_LINE)
						z += 1.8
			"asphalt":
				b.box(Vector3(rect.get_center().x, GROUND_Y - 0.03, rect.get_center().y), Vector3(rect.size.x, 0.04, rect.size.y), Pal.ASPHALT.lightened(0.06))
			"dirt":
				b.box(Vector3(rect.get_center().x, GROUND_Y - 0.02, rect.get_center().y), Vector3(rect.size.x, 0.04, rect.size.y), Pal.DIRT)
			"parking":
				b.box(Vector3(rect.get_center().x, GROUND_Y - 0.03, rect.get_center().y), Vector3(rect.size.x, 0.04, rect.size.y), Pal.ASPHALT.lightened(0.04))
				var px := rect.position.x
				while px <= rect.end.x:
					b.box(Vector3(px, GROUND_Y - 0.005, rect.get_center().y), Vector3(0.08, 0.01, rect.size.y - 0.4), Pal.ROAD_LINE)
					px += 2.5
	_mi(b.commit(Models.mat_main()), _static, false)


# -----------------------------------------------------------------------------
# Floors
# -----------------------------------------------------------------------------

func _build_floors() -> void:
	var b := MeshBuilder.new()
	b.ao_strength = 0.0
	b.contact_shade = 0.0
	var rng := RandomNumberGenerator.new()
	for room in grid.rooms:
		var rt: RoomTypeDef = Content.room_type(room["type"])
		if rt == null:
			continue
		var rect: Rect2i = room["rect"]
		rng.seed = hash(room["id"])
		# Grout / base slab under the tiles
		b.box(Vector3(rect.get_center().x, FLOOR_Y - 0.06, rect.get_center().y), Vector3(rect.size.x, 0.1, rect.size.y), rt.floor_b.darkened(0.25))
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				_floor_cell(b, rt, Vector2i(x, z), rng)
		if rt.floor_style == "loading":
			# Hazard edge along the building side
			for z in range(rect.position.y, rect.end.y):
				for k in 2:
					var col := Pal.HAZARD if (z + k) % 2 == 0 else Pal.CHARCOAL
					b.box(Vector3(rect.position.x + 0.1, FLOOR_Y + 0.002, z + 0.25 + k * 0.5), Vector3(0.16, 0.012, 0.48), col)
	# Delivery pads
	for c in grid.delivery_zone:
		b.box(Vector3(c.x + 0.5, FLOOR_Y + 0.004, c.y + 0.5), Vector3(0.9, 0.006, 0.9), Pal.HAZARD.darkened(0.05))
		b.box(Vector3(c.x + 0.5, FLOOR_Y + 0.008, c.y + 0.5), Vector3(0.76, 0.006, 0.76), Pal.CONCRETE)
	_mi(b.commit(Models.mat_main()), _static, false)


func _floor_cell(b: MeshBuilder, rt: RoomTypeDef, c: Vector2i, rng: RandomNumberGenerator) -> void:
	var x := float(c.x)
	var z := float(c.y)
	match rt.floor_style:
		"tile_checker":
			for i in 2:
				for j in 2:
					var col := rt.floor_a if (c.x * 2 + i + c.y * 2 + j) % 2 == 0 else rt.floor_b
					b.box(Vector3(x + 0.25 + i * 0.5, FLOOR_Y - 0.01, z + 0.25 + j * 0.5), Vector3(0.48, 0.02, 0.48), col, 0.006)
		"planks":
			for k in 4:
				var row := c.y * 4 + k
				var shade := [Pal.PLANK_A, Pal.PLANK_B, Pal.PLANK_C][(row * 7 + c.x * 3) % 3] as Color
				shade = shade.lerp(rt.floor_a, 0.35).darkened(rng.randf() * 0.05)
				b.box(Vector3(x + 0.5, FLOOR_Y - 0.01, z + 0.125 + k * 0.25), Vector3(0.995, 0.02, 0.235), shade, 0.006)
		"concrete":
			var col2 := rt.floor_a.darkened(rng.randf() * 0.05)
			b.box(Vector3(x + 0.5, FLOOR_Y - 0.01, z + 0.5), Vector3(0.985, 0.02, 0.985), col2, 0.004)
		"cold_tile":
			for i in 3:
				for j in 3:
					var col3 := rt.floor_a if (i + j) % 2 == 0 else rt.floor_b
					b.box(Vector3(x + 1.0 / 6.0 + i / 3.0, FLOOR_Y - 0.01, z + 1.0 / 6.0 + j / 3.0), Vector3(0.32, 0.02, 0.32), col3, 0.004)
		"patio":
			var col4 := rt.floor_a.lerp(rt.floor_b, rng.randf())
			b.box(Vector3(x + 0.5, FLOOR_Y - 0.01, z + 0.5), Vector3(0.94, 0.02, 0.94), col4, 0.02)
		"loading":
			var col5 := rt.floor_a.darkened(rng.randf() * 0.04)
			b.box(Vector3(x + 0.5, FLOOR_Y - 0.01, z + 0.5), Vector3(0.99, 0.02, 0.99), col5, 0.003)
		_:
			b.box(Vector3(x + 0.5, FLOOR_Y - 0.01, z + 0.5), Vector3(0.98, 0.02, 0.98), rt.floor_a, 0.005)


# -----------------------------------------------------------------------------
# Walls, windows, doors
# -----------------------------------------------------------------------------

func _wall_color_for(c: Vector2i) -> Color:
	var rt := grid.room_type_at(c)
	if rt == null or rt.outdoor:
		return Pal.FACADE
	return rt.wall_color


func _build_walls() -> void:
	var b := MeshBuilder.new()
	b.ao_strength = 0.12
	b.contact_shade = 0.0
	var glass := MeshBuilder.new()
	var fence := MeshBuilder.new()
	var done := {}
	for room in grid.rooms:
		var rect: Rect2i = room["rect"]
		for x in range(rect.position.x - 1, rect.end.x + 1):
			for z in range(rect.position.y - 1, rect.end.y + 1):
				var a := Vector2i(x, z)
				for d in [Vector2i(1, 0), Vector2i(0, 1)]:
					var n: Vector2i = a + d
					var key := RestaurantGrid.edge_key(a, n)
					if done.has(key):
						continue
					if grid.room_index(a) == grid.room_index(n):
						continue
					if grid.room_index(a) < 0 and grid.room_index(n) < 0:
						continue
					done[key] = true
					var opening := grid.opening_type(a, n)
					if opening != "":
						_door(b, a, n, opening)
						continue
					if grid.fence_between(a, n):
						_fence_segment(fence, a, n)
					elif grid.wall_between(a, n):
						_wall_segment(b, glass, a, n)
	_mi(b.commit(Models.mat_main()), _static)
	if not fence.is_empty():
		_mi(fence.commit(Models.mat_main()), _static)
	if not glass.is_empty():
		var gm := _mi(glass.commit(Models.mat_emissive(Color("cfeaf2"), 0.25)), _static, false)
		window_glass.push_back(gm)


## True if this wall should be cut low so the camera can see past it.
func _is_low(a: Vector2i, n: Vector2i) -> bool:
	if a.y == n.y:
		# Wall runs along Z (side wall). Keep tall.
		return false
	# Wall runs along X. North cell = a (smaller z). Tall only if the north
	# side is outside the building (a back wall).
	var north := a if a.y < n.y else n
	return grid.room_index(north) >= 0 and _is_indoor(north)


func _is_indoor(c: Vector2i) -> bool:
	var rt := grid.room_type_at(c)
	return rt != null and not rt.outdoor


func _wall_segment(b: MeshBuilder, glass: MeshBuilder, a: Vector2i, n: Vector2i) -> void:
	var low := _is_low(a, n)
	var h := WALL_LOW if low else WALL_TALL
	var col_a := _wall_color_for(a)
	var col_n := _wall_color_for(n)
	var along_x := a.x == n.x   # edge between z and z+1 -> wall runs along X
	var center: Vector3
	var length := 1.0 + WALL_T
	if along_x:
		center = Vector3(a.x + 0.5, 0, maxi(a.y, n.y))
	else:
		center = Vector3(maxi(a.x, n.x), 0, a.y + 0.5)
	# Which side faces cell a?
	var side_a := Vector3(a.x + 0.5, 0, a.y + 0.5) - center
	side_a = Vector3(signf(side_a.x), 0, signf(side_a.z))
	var window := false
	if not low and (grid.room_index(a) < 0 or grid.room_index(n) < 0):
		var inner := a if grid.room_index(a) >= 0 else n
		var rt := grid.room_type_at(inner)
		if rt and not rt.outdoor and rt.id != &"storage" and rt.id != &"cooler":
			var coord := inner.x if along_x else inner.y
			window = posmod(coord, 3) == 1
	var size_full := Vector3(length if along_x else WALL_T, h, WALL_T if along_x else length)
	var half := Vector3(length if along_x else WALL_T * 0.5, h, WALL_T * 0.5 if along_x else length)
	var off := side_a * WALL_T * 0.25
	if window:
		_window_wall(b, glass, center, along_x, side_a, col_a, col_n)
	else:
		b.block(center + off, half, col_a, 0.0)
		b.block(center - off, half, col_n, 0.0)
		# Baseboards on interior faces
		for s in [1.0, -1.0]:
			var c: Vector3 = center + side_a * s * (WALL_T * 0.5 + 0.012)
			var inside_cell := a if s > 0.0 else n
			if _is_indoor(inside_cell) and h > 0.2:
				var bb := Vector3(length - 0.02 if along_x else 0.03, 0.12, 0.03 if along_x else length - 0.02)
				b.block(c, bb, Pal.BASEBOARD, 0.006)
	# Section-cut cap
	b.block(center + Vector3(0, h, 0), Vector3(size_full.x + 0.02, 0.045, size_full.z + 0.02), Pal.WALL_CAP, 0.012)
	_add_wall_collider(center, size_full, low)


func _window_wall(b: MeshBuilder, glass: MeshBuilder, center: Vector3, along_x: bool, side_a: Vector3, col_a: Color, col_n: Color) -> void:
	var length := 1.0 + WALL_T
	var sill := 0.95
	var head := 1.95
	var off := side_a * WALL_T * 0.25
	var half_lo := Vector3(length if along_x else WALL_T * 0.5, sill, WALL_T * 0.5 if along_x else length)
	var half_hi := Vector3(length if along_x else WALL_T * 0.5, WALL_TALL - head, WALL_T * 0.5 if along_x else length)
	b.block(center + off, half_lo, col_a)
	b.block(center - off, half_lo, col_n)
	b.block(center + off + Vector3(0, head, 0), half_hi, col_a)
	b.block(center - off + Vector3(0, head, 0), half_hi, col_n)
	# Side posts of the opening
	var post := Vector3(0.22 if along_x else WALL_T, head - sill, WALL_T if along_x else 0.22)
	var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	for s in [-1.0, 1.0]:
		b.block(center + axis * s * (length * 0.5 - 0.11) + Vector3(0, sill, 0), post, col_a)
	# Chunky window frame + sill
	var fw := Pal.WINDOW_FRAME
	var frame_len := length - 0.44
	var fsz := Vector3(frame_len if along_x else WALL_T + 0.08, 0.07, WALL_T + 0.08 if along_x else frame_len)
	b.block(center + Vector3(0, sill - 0.02, 0), fsz + (Vector3(0.1, 0, 0.06) if along_x else Vector3(0.06, 0, 0.1)), fw, 0.02)
	b.block(center + Vector3(0, head - 0.06, 0), fsz, fw, 0.02)
	var mull := Vector3(0.06 if along_x else WALL_T + 0.04, head - sill, WALL_T + 0.04 if along_x else 0.06)
	b.block(center + Vector3(0, sill, 0), mull, fw, 0.01)
	var gsz := Vector3(frame_len if along_x else 0.03, head - sill, 0.03 if along_x else frame_len)
	glass.block(center + Vector3(0, sill, 0), gsz, Color(1, 1, 1))


func _door(b: MeshBuilder, a: Vector2i, n: Vector2i, type: String) -> void:
	var along_x := a.x == n.x
	var center: Vector3
	if along_x:
		center = Vector3(a.x + 0.5, 0, maxi(a.y, n.y))
	else:
		center = Vector3(maxi(a.x, n.x), 0, a.y + 0.5)
	var low := _is_low(a, n)
	var h := WALL_LOW if low else WALL_TALL
	var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var frame_col := Pal.DOOR_WOOD
	if type == "roller":
		frame_col = Pal.STEEL_DARK
	# Door posts (substantial frames)
	var post_h := maxf(h, 1.0) if low else 2.15
	for s in [-1.0, 1.0]:
		var p: Vector3 = center + axis * s * 0.52
		b.block(p, Vector3(0.12 if along_x else WALL_T + 0.1, post_h, WALL_T + 0.1 if along_x else 0.12), frame_col, 0.02)
	if not low:
		# Lintel + wall above the door
		var above := Vector3(1.0 + WALL_T if along_x else WALL_T, WALL_TALL - 2.15, WALL_T if along_x else 1.0 + WALL_T)
		var ca := _wall_color_for(a)
		b.block(center + Vector3(0, 2.15, 0), above, ca)
		b.block(center + Vector3(0, 2.1, 0), Vector3(1.16 if along_x else WALL_T + 0.1, 0.12, WALL_T + 0.1 if along_x else 1.16), frame_col, 0.02)
		b.block(center + Vector3(0, WALL_TALL, 0), Vector3(above.x + 0.02, 0.045, above.z + 0.02), Pal.WALL_CAP, 0.012)
		if type == "roller":
			b.box(center + Vector3(0, 1.98, 0), Vector3(1.0 if along_x else 0.3, 0.26, 0.3 if along_x else 1.0), Pal.STEEL, 0.06)
	else:
		for s in [-1.0, 1.0]:
			var p2: Vector3 = center + axis * s * 0.52
			b.block(p2 + Vector3(0, post_h, 0), Vector3(0.16 if along_x else WALL_T + 0.14, 0.05, WALL_T + 0.14 if along_x else 0.16), Pal.WALL_CAP, 0.012)
	# Threshold
	b.block(center + Vector3(0, -0.005, 0), Vector3(0.95 if along_x else WALL_T + 0.04, 0.02, WALL_T + 0.04 if along_x else 0.95), Pal.WALNUT, 0.005)
	if type == "front":
		# Welcome mat on the outside
		var out_cell := n if grid.room_index(n) < 0 else a
		var mat_pos := Vector3(out_cell.x + 0.5, GROUND_Y + 0.045, out_cell.y + 0.5)
		b.block(mat_pos, Vector3(0.8, 0.015, 0.55), Pal.DINER_RED.darkened(0.2), 0.005)
		b.block(mat_pos + Vector3(0, 0.015, 0), Vector3(0.6, 0.004, 0.35), Pal.MUSTARD)
	if type == "swing" or type == "front":
		_swing_door(center, along_x, type == "front")


func _swing_door(center: Vector3, along_x: bool, front: bool) -> void:
	var door := SwingDoor.new()
	door.position = center
	door.rotation.y = 0.0 if along_x else PI * 0.5
	door.half_height = 0.55 if front else 0.75
	door.color = Pal.DOOR_WOOD if not front else Pal.TEAL
	_doors.add_child(door)
	swing_doors.push_back(door)


func _fence_segment(b: MeshBuilder, a: Vector2i, n: Vector2i) -> void:
	# Low picket fence between outdoor areas and the street (only where one
	# side is an outdoor room and the other is not part of the building).
	var ra := grid.room_index(a)
	var rn := grid.room_index(n)
	if ra >= 0 and rn >= 0:
		return
	var inner := a if ra >= 0 else n
	var rt := grid.room_type_at(inner)
	if rt == null or not rt.outdoor or rt.id == &"loading":
		return
	var along_x := a.x == n.x
	var center: Vector3
	if along_x:
		center = Vector3(a.x + 0.5, 0, maxi(a.y, n.y))
	else:
		center = Vector3(maxi(a.x, n.x), 0, a.y + 0.5)
	var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	b.block(center + Vector3(0, 0.32, 0), Vector3(1.0 if along_x else 0.05, 0.06, 0.05 if along_x else 1.0), Pal.CREAM, 0.012)
	for k in 4:
		var p := center + axis * (-0.375 + k * 0.25)
		b.block(p, Vector3(0.07, 0.48, 0.07), Pal.CREAM, 0.012)
		b.block(p + Vector3(0, 0.48, 0), Vector3(0.05, 0.05, 0.05), Pal.CREAM.darkened(0.08), 0.01)
	_add_wall_collider(center, Vector3(1.0 if along_x else 0.1, 0.6, 0.1 if along_x else 1.0), true)


func _add_wall_collider(center: Vector3, size: Vector3, _low: bool) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(maxf(size.x, 0.1), 2.0, maxf(size.z, 0.1))
	cs.shape = sh
	cs.position = center + Vector3(0, 1.0, 0)
	_body.add_child(cs)


func _build_bounds() -> void:
	var lot := grid.lot
	var t := 1.0
	var rects := [
		[Vector3(lot.get_center().x, 1, lot.position.y - t * 0.5), Vector3(lot.size.x + 2 * t, 2, t)],
		[Vector3(lot.get_center().x, 1, lot.end.y + t * 0.5), Vector3(lot.size.x + 2 * t, 2, t)],
		[Vector3(lot.position.x - t * 0.5, 1, lot.get_center().y), Vector3(t, 2, lot.size.y)],
		[Vector3(lot.end.x + t * 0.5, 1, lot.get_center().y), Vector3(t, 2, lot.size.y)],
	]
	for r in rects:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = r[1]
		cs.shape = sh
		cs.position = r[0]
		_body.add_child(cs)


# -----------------------------------------------------------------------------
# Lights and props
# -----------------------------------------------------------------------------

func _build_lights() -> void:
	for room in grid.rooms:
		var rt: RoomTypeDef = Content.room_type(room["type"])
		if rt == null or rt.outdoor:
			continue
		var rect: Rect2i = room["rect"]
		# One soft warm light per ~5x5 area keeps interiors bright and cosy.
		var nx := maxi(1, int(round(rect.size.x / 5.0)))
		var nz := maxi(1, int(round(rect.size.y / 5.0)))
		for i in nx:
			for j in nz:
				var l := OmniLight3D.new()
				l.position = Vector3(rect.position.x + rect.size.x * (i + 0.5) / nx, 2.6, rect.position.y + rect.size.y * (j + 0.5) / nz)
				l.light_color = rt.light_color
				l.light_energy = 0.0
				l.omni_range = maxf(rect.size.x / nx, rect.size.y / nz) * 0.95 + 1.5
				l.omni_attenuation = 1.2
				l.shadow_enabled = false
				l.light_specular = 0.2
				_lights.add_child(l)
				room_lights.push_back(l)


func _build_props() -> void:
	for p in _layout_props:
		var key := StringName(p["m"])
		var pos: Array = p["p"]
		var n := Models.instance(key)
		n.position = Vector3(pos[0], GROUND_Y + 0.02, pos[1])
		n.rotation.y = deg_to_rad(float(p.get("y", 0.0)))
		var s := float(p.get("s", 1.0))
		n.scale = Vector3(s, s, s)
		_props.add_child(n)
		if key == &"lamp_post":
			var l := OmniLight3D.new()
			l.position = n.position + Vector3(0, 2.85, 0.55).rotated(Vector3.UP, n.rotation.y)
			l.light_color = Color("ffd59a")
			l.light_energy = 0.0
			l.omni_range = 4.5
			l.add_to_group(&"street_lights")
			_props.add_child(l)
		if p.get("collide", false):
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			var sz: Array = p.get("size", [1, 1])
			sh.size = Vector3(sz[0], 2, sz[1])
			cs.shape = sh
			cs.position = n.position + Vector3(0, 1, 0)
			_body.add_child(cs)
	_build_pole_sign()


func _build_pole_sign() -> void:
	var at = grid.street.get("pole_sign")
	if not (at is Array):
		return
	var b := MeshBuilder.new()
	var base := Vector3(at[0], GROUND_Y, at[1])
	b.block(base, Vector3(0.5, 0.15, 0.5), Pal.CHARCOAL, 0.03)
	b.block(base + Vector3(0, 0.15, 0), Vector3(0.14, 3.3, 0.14), Pal.CHARCOAL, 0.02)
	# Big diner sign board
	var board := base + Vector3(0, 3.25, 0)
	b.box(board, Vector3(2.4, 1.0, 0.25), Pal.DINER_RED, 0.08)
	b.box(board + Vector3(0, 0, 0.13), Vector3(2.1, 0.72, 0.02), Pal.CREAM, 0.02)
	b.box(board + Vector3(0, 0.62, 0), Vector3(1.4, 0.3, 0.2), Pal.MUSTARD, 0.06)
	_mi(b.commit(Models.mat_main()), _props)
	var lbl := Label3D.new()
	lbl.text = "DINER"
	lbl.font = load("res://art/fonts/AlfaSlabOne-Regular.ttf")
	lbl.font_size = 96
	lbl.pixel_size = 0.0055
	lbl.modulate = Pal.DINER_RED
	lbl.outline_size = 0
	lbl.position = board + Vector3(0, -0.02, 0.15)
	lbl.shaded = false
	_props.add_child(lbl)
	var lbl2 := Label3D.new()
	lbl2.text = "EAT"
	lbl2.font = lbl.font
	lbl2.font_size = 64
	lbl2.pixel_size = 0.004
	lbl2.modulate = Pal.UI_INK
	lbl2.position = board + Vector3(0, 0.62, 0.11)
	_props.add_child(lbl2)


## Time-of-day hook: interior & street lights and window glow.
func set_light_level(interior: float, street_lights: float, window_glow: float) -> void:
	var dim := 1.0
	if power_dim > 0.0:
		dim = 0.15 + 0.1 * absf(sin(Time.get_ticks_msec() * 0.013))
	for l in room_lights:
		l.light_energy = interior * dim
	for l in get_tree().get_nodes_in_group(&"street_lights"):
		(l as OmniLight3D).light_energy = street_lights
	for g in window_glass:
		var m := Models.mat_emissive(Color("cfeaf2"), 0.25)
		g.material_override = null
		g.set_surface_override_material(0, Models.mat_emissive(Color("cfeaf2").lerp(Color("ffcf8a"), clampf(window_glow, 0, 1)), 0.25 + window_glow * 1.2))
