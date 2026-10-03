class_name ModelsFurniture
## Dining furniture, front-of-house fixtures and decor.

const TABLE_H := 0.72


static func build(key: StringName, b: MeshBuilder) -> bool:
	match key:
		&"table": _table(b)
		&"chair": _chair(b)
		&"terminal": _terminal(b)
		&"open_sign": _open_sign(b)
		&"open_sign_board": _open_sign_board(b)
		&"register": _register(b)
		&"plant_pot": _plant_pot(b)
		&"jukebox": _jukebox(b)
		&"jukebox_glow": _jukebox_glow(b)
		&"table_number": _table_number(b)
		&"table_cloth": _table_cloth(b)
		&"menu_board": _menu_board(b)
		_: return false
	return true


static func _table(b: MeshBuilder) -> void:
	var top := Pal.OAK
	var edge := Pal.WALNUT
	# Thick legs, slightly splayed in feel by chamfers
	for x in [-0.36, 0.36]:
		for z in [-0.36, 0.36]:
			b.block(Vector3(x, 0, z), Vector3(0.09, TABLE_H - 0.08, 0.09), edge, 0.018)
	b.block(Vector3(0, TABLE_H - 0.2, 0), Vector3(0.8, 0.1, 0.8), edge, 0.02)
	# Edge band stops 5 mm under the oak top so the two never share a plane
	b.block(Vector3(0, TABLE_H - 0.09, 0), Vector3(0.96, 0.085, 0.96), edge, 0.03)
	b.block(Vector3(0, TABLE_H - 0.02, 0), Vector3(0.9, 0.02, 0.9), top.lightened(0.04))


static func _chair(b: MeshBuilder) -> void:
	var wood := Pal.WALNUT
	var vinyl := Pal.DINER_RED
	for x in [-0.17, 0.17]:
		for z in [-0.17, 0.17]:
			b.block(Vector3(x, 0, z), Vector3(0.06, 0.42, 0.06), wood, 0.012)
	b.block(Vector3(0, 0.38, 0), Vector3(0.46, 0.05, 0.44), wood, 0.015)
	b.block(Vector3(0, 0.42, 0.005), Vector3(0.44, 0.07, 0.41), vinyl, 0.03)
	# Backrest posts and a chunky upholstered back
	for x in [-0.17, 0.17]:
		b.block(Vector3(x, 0.42, -0.19), Vector3(0.06, 0.42, 0.06), wood, 0.012)
	b.box(Vector3(0, 0.72, -0.2), Vector3(0.44, 0.22, 0.09), vinyl, 0.03)   # 5 mm proud of the posts
	b.box(Vector3(0, 0.72, -0.25), Vector3(0.38, 0.16, 0.02), vinyl.darkened(0.12), 0.006)


static func _terminal(b: MeshBuilder) -> void:
	# Manager's order desk: a chunky desk with a boxy monitor and a clipboard.
	var desk := Pal.OAK
	for x in [-0.4, 0.4]:
		b.block(Vector3(x, 0, 0), Vector3(0.12, 0.72, 0.7), Pal.WALNUT, 0.02)
	b.block(Vector3(0, 0.7, 0), Vector3(0.98, 0.07, 0.8), desk, 0.025)
	b.block(Vector3(0, 0.3, -0.3), Vector3(0.7, 0.36, 0.06), Pal.WALNUT.lightened(0.08), 0.015)
	# Monitor
	b.block(Vector3(0, 0.77, -0.15), Vector3(0.22, 0.05, 0.18), Pal.CREAM.darkened(0.1), 0.015)
	b.block(Vector3(0, 0.81, -0.15), Vector3(0.08, 0.12, 0.08), Pal.CREAM.darkened(0.1))
	b.box(Vector3(0, 1.08, -0.16), Vector3(0.5, 0.36, 0.32), Pal.CREAM, 0.05)
	b.box(Vector3(0, 1.08, 0.0), Vector3(0.42, 0.28, 0.02), Color("234a48"), 0.01)
	# Keyboard + clipboard
	b.block(Vector3(0, 0.77, 0.18), Vector3(0.42, 0.03, 0.14), Pal.CREAM.darkened(0.15), 0.01)
	b.push_at(Vector3(0.33, 0.775, 0.12), -0.25)
	b.block(Vector3.ZERO, Vector3(0.22, 0.015, 0.3), Pal.OAK_LIGHT.darkened(0.15), 0.004)
	b.block(Vector3(0, 0.015, 0.0), Vector3(0.18, 0.004, 0.24), Pal.CREAM)
	b.block(Vector3(0, 0.015, -0.13), Vector3(0.08, 0.02, 0.03), Pal.STEEL)
	b.pop()


static func _open_sign(b: MeshBuilder) -> void:
	# Free-standing sidewalk post with a crossbar; the board itself flips.
	b.block(Vector3(0, 0, 0), Vector3(0.5, 0.08, 0.4), Pal.CHARCOAL, 0.02)
	b.block(Vector3(0, 0.08, 0), Vector3(0.08, 1.55, 0.08), Pal.WALNUT, 0.015)
	b.box(Vector3(0, 1.6, 0), Vector3(0.8, 0.07, 0.07), Pal.WALNUT, 0.02)
	for x in [-0.3, 0.3]:
		b.box(Vector3(x, 1.52, 0), Vector3(0.02, 0.12, 0.02), Pal.STEEL_DARK)
	# A big chunky lever on the post
	b.box(Vector3(0.09, 0.95, 0.0), Vector3(0.08, 0.2, 0.1), Pal.STEEL_DARK, 0.02)


static func _open_sign_board(b: MeshBuilder) -> void:
	# Hangs from y = 0; front (+Z) says OPEN (green), back says CLOSED (red).
	b.box(Vector3(0, -0.24, 0), Vector3(0.78, 0.38, 0.05), Pal.CREAM, 0.02)
	b.box(Vector3(0, -0.24, 0.028), Vector3(0.7, 0.3, 0.01), Color("3e9c5a"), 0.008)
	b.box(Vector3(0, -0.24, -0.028), Vector3(0.7, 0.3, 0.01), Color("d24a3c"), 0.008)
	# Simple bold "bars" suggesting lettering
	for k in 4:
		b.box(Vector3(-0.24 + k * 0.16, -0.24, 0.035), Vector3(0.1, 0.16, 0.006), Pal.CREAM)
		b.box(Vector3(-0.24 + k * 0.16, -0.24, -0.035), Vector3(0.1, 0.04, 0.006), Pal.CREAM)


static func _register(b: MeshBuilder) -> void:
	ModelsKitchen.cabinet(b, Pal.OAK, Pal.OAK_LIGHT, 2)
	ModelsKitchen.worktop(b, Pal.BUTCHER)
	var y := ModelsKitchen.H
	b.block(Vector3(0, y, -0.1), Vector3(0.5, 0.14, 0.42), Pal.MUSTARD, 0.03)
	b.push_at(Vector3(0, y + 0.18, -0.06), 0.0, Vector3.ONE, -0.5)
	b.box(Vector3.ZERO, Vector3(0.44, 0.06, 0.3), Pal.CREAM, 0.02)
	for r in 3:
		for c in 4:
			b.box(Vector3(-0.15 + c * 0.1, 0.035, -0.09 + r * 0.09), Vector3(0.06, 0.02, 0.05), Pal.CHARCOAL, 0.006)
	b.pop()
	b.block(Vector3(0, y + 0.14, -0.28), Vector3(0.3, 0.2, 0.08), Pal.MUSTARD.darkened(0.08), 0.02)
	b.box(Vector3(0, y + 0.3, -0.245), Vector3(0.24, 0.08, 0.02), Color("234a48"))


static func _plant_pot(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.26, 0.42, Pal.BRICK, 8, 0.03, Color(0, 0, 0, 0), 0.3)
	b.cyl(Vector3(0, 0.38, 0), 0.31, 0.06, Pal.BRICK.darkened(0.1), 8, 0.015)
	b.cyl(Vector3(0, 0.42, 0), 0.27, 0.01, Pal.DIRT.darkened(0.3), 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 7:
		var a := TAU * k / 7.0
		var lean := 0.45
		b.push_at(Vector3(cos(a) * 0.05, 0.42, sin(a) * 0.05), -a, Vector3.ONE, 0.0, lean)
		b.box(Vector3(0.0, 0.35, 0), Vector3(0.09, 0.7, 0.03), Pal.LEAF.lightened(rng.randf() * 0.15), 0.01)
		b.pop()
	b.sphere(Vector3(0, 0.75, 0), Vector3(0.22, 0.25, 0.22), Pal.LEAF_LIGHT, 1, Color(0, 0, 0, 0), 0.15, 4)


static func _jukebox(b: MeshBuilder) -> void:
	var wood := Pal.WALNUT
	b.block(Vector3(0, 0, 0), Vector3(0.8, 0.9, 0.55), wood, 0.04)
	b.cyl(Vector3(0, 0.9, 0), 0.4, 0.3, wood, 10, 0.03, Color(0, 0, 0, 0), 0.25)
	b.box(Vector3(0, 0.55, 0.28), Vector3(0.6, 0.4, 0.03), Pal.CHARCOAL, 0.02)
	for k in 5:
		b.box(Vector3(-0.24 + k * 0.12, 0.25, 0.285), Vector3(0.06, 0.18, 0.02), Pal.STEEL)


static func _jukebox_glow(b: MeshBuilder) -> void:
	b.box(Vector3(0, 0.95, 0.24), Vector3(0.62, 0.16, 0.04), Color("ffb347"), 0.02)


## A diamond-set cloth on the table top. Built white; each table multiplies it
## by its own colour (the colour that names the table on order tickets).
static func _table_cloth(b: MeshBuilder) -> void:
	b.push_at(Vector3.ZERO, PI * 0.25)
	b.block(Vector3.ZERO, Vector3(0.5, 0.008, 0.5), Color(0.96, 0.96, 0.96), 0.003)
	b.block(Vector3.ZERO, Vector3(0.36, 0.014, 0.36), Color(0.82, 0.82, 0.82), 0.003)
	b.pop()


## Chalkboard menu on two posts, standing against a wall (face toward +Z).
## The chalk writing is added live by the MenuBoard component. It stands a
## little off the wall so a window frame behind it never pokes through.
static func _menu_board(b: MeshBuilder) -> void:
	var z := -0.25
	for x in [-0.47, 0.47]:
		b.block(Vector3(x, 0, z), Vector3(0.07, 1.78, 0.07), Pal.WALNUT, 0.015)
	b.block(Vector3(0, 0.7, z), Vector3(0.86, 1.0, 0.05), Color("2f3b36"), 0.0)
	# Frame stands 1.5 cm proud of the slate on every side
	var fz := 0.08
	b.block(Vector3(0, 0.64, z), Vector3(0.96, 0.06, fz), Pal.OAK, 0.012)
	b.block(Vector3(0, 1.7, z), Vector3(0.96, 0.06, fz), Pal.OAK, 0.012)
	for x in [-0.46, 0.46]:
		b.block(Vector3(x, 0.7, z), Vector3(0.06, 1.0, fz), Pal.OAK, 0.012)
	# Chalk ledge
	b.block(Vector3(0, 0.6, z + 0.07), Vector3(0.8, 0.04, 0.1), Pal.OAK, 0.01)
	b.block(Vector3(0.22, 0.64, z + 0.08), Vector3(0.07, 0.02, 0.02), Color(0.95, 0.95, 0.92))


static func _table_number(b: MeshBuilder) -> void:
	b.block(Vector3.ZERO, Vector3(0.12, 0.02, 0.06), Pal.WALNUT, 0.005)
	b.block(Vector3(0, 0.02, 0), Vector3(0.11, 0.1, 0.012), Pal.CREAM, 0.003)
