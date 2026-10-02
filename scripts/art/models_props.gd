class_name ModelsProps
## Containers, dishware, tools, vehicles, street props and mess decals.

## Interior floor height and usable size of each container type. Used to lay out
## the miniature ingredient units shown inside a crate.
const CONTAINER_INFO := {
	&"crate": {"floor": 0.05, "size": Vector2(0.52, 0.36), "height": 0.3},
	&"crate_cold": {"floor": 0.05, "size": Vector2(0.5, 0.34), "height": 0.26},
	&"sack": {"floor": 0.18, "size": Vector2(0.34, 0.3), "height": 0.34},
	&"carton": {"floor": 0.04, "size": Vector2(0.5, 0.36), "height": 0.26},
}


static func build(key: StringName, b: MeshBuilder) -> bool:
	match key:
		&"crate": _crate(b)
		&"crate_cold": _crate_cold(b)
		&"sack": _sack(b)
		&"carton": _carton(b)
		&"crate_label": _crate_label(b)
		&"plate": _plate(b, false)
		&"plate_dirty": _plate(b, true)
		&"mug": _mug(b, false)
		&"mug_dirty": _mug(b, true)
		&"extinguisher": _extinguisher(b)
		&"mop": _mop(b)
		&"flatpack": _flatpack(b)
		&"trash_bag": _trash_bag(b)
		&"truck": _truck(b)
		&"truck_wheel": _wheel(b, 0.3)
		&"van": _van(b)
		&"tree": _tree(b)
		&"bush": _bush(b)
		&"lamp_post": _lamp_post(b)
		&"bench": _bench(b)
		&"hydrant": _hydrant(b)
		&"car": _car(b)
		&"for_sale_sign": _for_sale_sign(b)
		&"cone": _cone(b)
		&"pallet": _pallet(b)
		&"mailbox": _mailbox(b)
		&"street_planter": _street_planter(b)
		&"mess_spill": _mess_spill(b)
		&"mess_trash": _mess_trash(b)
		&"dumpster": _dumpster(b)
		&"awning": _awning(b)
		&"ping_marker": _ping_marker(b)
		&"ring": _ring(b)
		&"steam_puff": _puff(b)
		_: return false
	return true


# -----------------------------------------------------------------------------
# Containers (open topped, contents are shown by the item)
# -----------------------------------------------------------------------------

static func _crate(b: MeshBuilder) -> void:
	var w := 0.62
	var d := 0.46
	var h := 0.3
	var c := Pal.CRATE
	var dk := Pal.CRATE_DARK
	b.block(Vector3(0, 0, 0), Vector3(w - 0.04, 0.05, d - 0.04), dk, 0.01)
	# Slatted walls: two slats per side with a gap
	for y in [0.04, 0.17]:
		b.block(Vector3(0, y, d * 0.5 - 0.02), Vector3(w, 0.1, 0.04), c, 0.012)
		b.block(Vector3(0, y, -d * 0.5 + 0.02), Vector3(w, 0.1, 0.04), c, 0.012)
		b.block(Vector3(w * 0.5 - 0.02, y, 0), Vector3(0.04, 0.1, d - 0.06), c.darkened(0.04), 0.012)
		b.block(Vector3(-w * 0.5 + 0.02, y, 0), Vector3(0.04, 0.1, d - 0.06), c.darkened(0.04), 0.012)
	# Corner posts + hand holes
	for x in [-w * 0.5 + 0.03, w * 0.5 - 0.03]:
		for z in [-d * 0.5 + 0.03, d * 0.5 - 0.03]:
			b.block(Vector3(x, 0, z), Vector3(0.06, h, 0.06), dk, 0.012)
	for x in [-w * 0.5 - 0.003, w * 0.5 + 0.003]:
		b.box(Vector3(x, 0.22, 0), Vector3(0.012, 0.035, 0.14), Pal.WALL_CAP)


static func _crate_cold(b: MeshBuilder) -> void:
	var c := Color("8fb3c9")
	var w := 0.6
	var d := 0.44
	var h := 0.26
	b.block(Vector3(0, 0, 0), Vector3(w - 0.06, 0.04, d - 0.06), c.darkened(0.15), 0.01)
	b.block(Vector3(0, 0.02, d * 0.5 - 0.025), Vector3(w, h - 0.02, 0.05), c, 0.02)
	b.block(Vector3(0, 0.02, -d * 0.5 + 0.025), Vector3(w, h - 0.02, 0.05), c, 0.02)
	b.block(Vector3(w * 0.5 - 0.025, 0.02, 0), Vector3(0.05, h - 0.02, d - 0.02), c.darkened(0.05), 0.02)
	b.block(Vector3(-w * 0.5 + 0.025, 0.02, 0), Vector3(0.05, h - 0.02, d - 0.02), c.darkened(0.05), 0.02)
	# Rolled rim
	b.box(Vector3(0, h, d * 0.5 - 0.02), Vector3(w + 0.02, 0.03, 0.07), c.lightened(0.1), 0.012)
	b.box(Vector3(0, h, -d * 0.5 + 0.02), Vector3(w + 0.02, 0.03, 0.07), c.lightened(0.1), 0.012)
	# Snowflake-ish badge = keep cold
	b.box(Vector3(0, 0.14, d * 0.5 + 0.003), Vector3(0.12, 0.08, 0.01), Pal.CREAM, 0.004)
	b.box(Vector3(0, 0.14, d * 0.5 + 0.009), Vector3(0.07, 0.016, 0.004), Color("3e8fe8"))
	b.box(Vector3(0, 0.14, d * 0.5 + 0.009), Vector3(0.016, 0.06, 0.004), Color("3e8fe8"))


static func _sack(b: MeshBuilder) -> void:
	b.jitter = 0.01
	b.cyl(Vector3.ZERO, 0.24, 0.12, Pal.SACK, 9, 0.04, Color(0, 0, 0, 0), 0.26)
	b.cyl(Vector3(0, 0.12, 0), 0.26, 0.12, Pal.SACK, 9, 0.0, Color(0, 0, 0, 0), 0.22)
	b.jitter = 0.0
	# Rolled-down rim
	b.cyl(Vector3(0, 0.22, 0), 0.235, 0.07, Pal.SACK.darkened(0.12), 9, 0.025)
	b.box(Vector3(0, 0.12, 0.25), Vector3(0.18, 0.1, 0.01), Pal.CREAM.darkened(0.05), 0.003)


static func _carton(b: MeshBuilder) -> void:
	var c := Pal.CARDBOARD
	var w := 0.6
	var d := 0.44
	var h := 0.26
	b.block(Vector3(0, 0, 0), Vector3(w, 0.03, d), c.darkened(0.1))
	b.block(Vector3(0, 0, d * 0.5 - 0.012), Vector3(w, h, 0.024), c, 0.006)
	b.block(Vector3(0, 0, -d * 0.5 + 0.012), Vector3(w, h, 0.024), c, 0.006)
	b.block(Vector3(w * 0.5 - 0.012, 0, 0), Vector3(0.024, h, d), c.darkened(0.05), 0.006)
	b.block(Vector3(-w * 0.5 + 0.012, 0, 0), Vector3(0.024, h, d), c.darkened(0.05), 0.006)
	# Flaps folded outward
	for s in [-1.0, 1.0]:
		b.push_at(Vector3(s * (w * 0.5 + 0.06), h - 0.01, 0), 0.0, Vector3.ONE, 0.0, s * -0.5)
		b.box(Vector3.ZERO, Vector3(0.14, 0.012, d - 0.02), c.lightened(0.05), 0.003)
		b.pop()
	b.box(Vector3(0, 0.13, d * 0.5 + 0.002), Vector3(0.3, 0.012, 0.004), Pal.CREAM)


static func _crate_label(b: MeshBuilder) -> void:
	# Coloured ingredient tag hung on the front of a container (tinted per item).
	b.box(Vector3(0, 0, 0), Vector3(0.2, 0.11, 0.012), Color(1, 1, 1), 0.005)


# -----------------------------------------------------------------------------
# Dishware (slightly oversized for readability)
# -----------------------------------------------------------------------------

static func _plate(b: MeshBuilder, dirty: bool) -> void:
	b.cyl(Vector3.ZERO, 0.16, 0.012, Pal.PLATE_RIM, 12)
	b.cyl(Vector3(0, 0.008, 0), 0.2, 0.026, Pal.PLATE, 12, 0.01, Pal.PLATE_RIM, 0.215)
	b.cyl(Vector3(0, 0.024, 0), 0.15, 0.006, Pal.PLATE, 12)
	if dirty:
		var rng := RandomNumberGenerator.new()
		rng.seed = 8
		for k in 5:
			var a := rng.randf() * TAU
			var rr := rng.randf_range(0.02, 0.12)
			b.push_at(Vector3(cos(a) * rr, 0.03, sin(a) * rr), rng.randf() * TAU)
			b.box(Vector3.ZERO, Vector3(rng.randf_range(0.04, 0.08), 0.006, rng.randf_range(0.03, 0.05)), Pal.DIRTY.darkened(rng.randf() * 0.25), 0.002)
			b.pop()


static func _mug(b: MeshBuilder, dirty: bool) -> void:
	b.cyl(Vector3.ZERO, 0.072, 0.12, Pal.MUG, 10, 0.012, Color(0, 0, 0, 0), 0.08)
	b.cyl(Vector3(0, 0.112, 0), 0.066, 0.009, Pal.CREAM.darkened(0.05), 10)
	b.box(Vector3(0.1, 0.06, 0), Vector3(0.03, 0.075, 0.025), Pal.MUG, 0.01)
	b.box(Vector3(0.082, 0.096, 0), Vector3(0.04, 0.022, 0.025), Pal.MUG, 0.008)
	b.box(Vector3(0.082, 0.026, 0), Vector3(0.04, 0.022, 0.025), Pal.MUG, 0.008)
	if dirty:
		b.cyl(Vector3(0, 0.121, 0), 0.06, 0.003, Pal.COFFEE.lightened(0.15), 8)
		b.box(Vector3(0.02, 0.1, 0.072), Vector3(0.03, 0.03, 0.006), Pal.COFFEE)


# -----------------------------------------------------------------------------
# Tools & packages
# -----------------------------------------------------------------------------

static func _extinguisher(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.09, 0.42, Pal.FIRE_RED, 8, 0.03)
	b.cyl(Vector3(0, 0.42, 0), 0.05, 0.05, Pal.CHARCOAL, 8)
	b.box(Vector3(0, 0.49, 0.0), Vector3(0.05, 0.05, 0.16), Pal.CHARCOAL, 0.012)
	b.box(Vector3(0, 0.51, -0.04), Vector3(0.04, 0.02, 0.14), Pal.STEEL, 0.008)
	b.box(Vector3(0, 0.46, 0.1), Vector3(0.04, 0.04, 0.08), Pal.RUBBER, 0.012)
	b.box(Vector3(0, 0.24, 0.088), Vector3(0.12, 0.12, 0.01), Pal.CREAM, 0.004)


static func _mop(b: MeshBuilder) -> void:
	b.block(Vector3(0, 0.0, 0), Vector3(0.05, 1.1, 0.05), Pal.OAK_LIGHT, 0.012)
	b.block(Vector3(0, -0.02, 0), Vector3(0.16, 0.06, 0.1), Pal.STEEL_DARK, 0.015)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for k in 8:
		var a := TAU * k / 8.0
		b.push_at(Vector3(cos(a) * 0.05, -0.02, sin(a) * 0.04), a, Vector3.ONE, 0.0, 0.25)
		b.box(Vector3(0, -0.07, 0), Vector3(0.03, 0.16, 0.03), Color("e8e2d0").darkened(rng.randf() * 0.1), 0.006)
		b.pop()


static func _flatpack(b: MeshBuilder) -> void:
	var c := Pal.CARDBOARD
	b.block(Vector3.ZERO, Vector3(0.72, 0.42, 0.56), c, 0.02)
	b.box(Vector3(0, 0.425, 0), Vector3(0.12, 0.012, 0.57), Color("e9d9a6"))
	b.box(Vector3(0, 0.21, 0.283), Vector3(0.12, 0.42, 0.008), Color("e9d9a6"))
	# "This side up" arrows + fragile glass sign
	for x in [-0.24, 0.24]:
		b.box(Vector3(x, 0.24, 0.284), Vector3(0.05, 0.14, 0.006), Pal.WALL_CAP)
		b.box(Vector3(x, 0.32, 0.284), Vector3(0.1, 0.03, 0.006), Pal.WALL_CAP)
	b.box(Vector3(0.0, 0.3, -0.284), Vector3(0.2, 0.16, 0.006), Pal.DINER_RED)


static func _trash_bag(b: MeshBuilder) -> void:
	b.jitter = 0.012
	b.sphere(Vector3(0, 0.18, 0), Vector3(0.22, 0.19, 0.2), Color("39403f"), 1, Color(0, 0, 0, 0), 0.1, 6)
	b.jitter = 0.0
	b.cyl(Vector3(0, 0.34, 0), 0.05, 0.06, Color("39403f"), 6, 0.0, Color(0, 0, 0, 0), 0.02)
	b.box(Vector3(0, 0.4, 0), Vector3(0.1, 0.04, 0.02), Pal.MUSTARD, 0.008)


# -----------------------------------------------------------------------------
# Vehicles
# -----------------------------------------------------------------------------

static func _wheel(b: MeshBuilder, r: float) -> void:
	b.push_at(Vector3.ZERO, 0.0, Vector3.ONE, 0.0, PI / 2.0)
	b.cyl(Vector3(0, -0.11, 0), r, 0.22, Pal.RUBBER, 10, 0.04)
	b.cyl(Vector3(0, 0.1, 0), r * 0.5, 0.03, Pal.STEEL, 8, 0.01)
	b.pop()


static func _truck(b: MeshBuilder) -> void:
	# Delivery box truck, facing +Z (cab at the front). Length ~5 m.
	var body := Color("f2e6d3")
	var cab := Pal.TEAL
	b.block(Vector3(0, 0.45, 0), Vector3(2.0, 0.25, 5.0), Pal.CHARCOAL, 0.04)
	# Cargo box
	b.block(Vector3(0, 0.68, -0.7), Vector3(2.1, 2.0, 3.4), body, 0.08)
	b.box(Vector3(1.06, 1.7, -0.7), Vector3(0.02, 0.5, 2.8), Pal.MUSTARD)
	b.box(Vector3(-1.06, 1.7, -0.7), Vector3(0.02, 0.5, 2.8), Pal.MUSTARD)
	b.box(Vector3(1.065, 1.2, -0.7), Vector3(0.02, 0.3, 2.0), cab)
	b.box(Vector3(-1.065, 1.2, -0.7), Vector3(0.02, 0.3, 2.0), cab)
	# Roller door at the back
	b.box(Vector3(0, 1.62, -2.41), Vector3(1.8, 1.8, 0.02), body.darkened(0.08), 0.01)
	for k in 6:
		b.box(Vector3(0, 0.85 + k * 0.28, -2.425), Vector3(1.8, 0.02, 0.01), body.darkened(0.2))
	# Cab
	b.block(Vector3(0, 0.6, 1.75), Vector3(2.0, 1.25, 1.5), cab, 0.12)
	b.box(Vector3(0, 1.6, 1.55), Vector3(1.9, 0.5, 1.0), cab, 0.12)
	b.box(Vector3(0, 1.55, 2.06), Vector3(1.7, 0.45, 0.02), Pal.WINDOW_GLASS.darkened(0.25), 0.01)
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * 1.0, 1.55, 1.6), Vector3(0.02, 0.4, 0.7), Pal.WINDOW_GLASS.darkened(0.25))
	b.box(Vector3(0, 0.95, 2.51), Vector3(1.9, 0.3, 0.04), Pal.STEEL_DARK, 0.02)
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * 0.75, 0.95, 2.53), Vector3(0.25, 0.14, 0.02), Color("fff1c4"), 0.01)
	b.block(Vector3(0, 0.45, 2.4), Vector3(2.05, 0.2, 0.3), Pal.STEEL, 0.04)


static func _van(b: MeshBuilder) -> void:
	var body := Pal.MUSTARD
	b.block(Vector3(0, 0.35, 0), Vector3(1.7, 1.5, 3.6), body, 0.15)
	b.box(Vector3(0, 1.45, 1.35), Vector3(1.5, 0.45, 0.6), Pal.WINDOW_GLASS.darkened(0.25), 0.05)
	b.box(Vector3(0, 1.05, 0.0), Vector3(1.72, 0.25, 2.0), Pal.CREAM)
	b.box(Vector3(0, 0.6, 1.81), Vector3(1.5, 0.2, 0.02), Pal.STEEL_DARK)


static func _car(b: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	var body := Color("c96f5a")
	b.block(Vector3(0, 0.25, 0), Vector3(1.6, 0.55, 3.4), body, 0.15)
	b.block(Vector3(0, 0.78, -0.2), Vector3(1.4, 0.5, 1.8), body.lightened(0.05), 0.15)
	b.box(Vector3(0, 1.03, -0.2), Vector3(1.42, 0.3, 1.6), Pal.WINDOW_GLASS.darkened(0.3), 0.08)
	for x in [-0.7, 0.7]:
		for z in [-1.1, 1.1]:
			b.push_at(Vector3(x, 0.3, z), 0.0, Vector3.ONE, 0.0, PI / 2.0)
			b.cyl(Vector3(0, -0.1, 0), 0.3, 0.2, Pal.RUBBER, 8, 0.04)
			b.pop()


# -----------------------------------------------------------------------------
# Street and lot
# -----------------------------------------------------------------------------

static func _tree(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.14, 1.4, Pal.TRUNK, 6, 0.02, Color(0, 0, 0, 0), 0.1)
	b.sphere(Vector3(0, 1.8, 0), Vector3(0.95, 0.85, 0.95), Pal.LEAF, 1, Pal.LEAF_LIGHT, 0.12, 1)
	b.sphere(Vector3(0.45, 1.4, 0.3), Vector3(0.55, 0.5, 0.55), Pal.LEAF.darkened(0.05), 1, Pal.LEAF_LIGHT, 0.12, 2)
	b.sphere(Vector3(-0.4, 2.3, -0.2), Vector3(0.6, 0.5, 0.6), Pal.LEAF, 1, Pal.LEAF_LIGHT.lightened(0.05), 0.12, 3)


static func _bush(b: MeshBuilder) -> void:
	b.sphere(Vector3(0, 0.3, 0), Vector3(0.5, 0.35, 0.45), Pal.LEAF, 1, Pal.LEAF_LIGHT, 0.15, 5)
	b.sphere(Vector3(0.35, 0.25, 0.1), Vector3(0.32, 0.26, 0.3), Pal.LEAF.darkened(0.05), 1, Pal.LEAF_LIGHT, 0.15, 6)


static func _lamp_post(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.16, 0.25, Pal.CHARCOAL, 8, 0.03)
	b.cyl(Vector3(0, 0.25, 0), 0.06, 2.9, Pal.CHARCOAL, 8, 0.0, Color(0, 0, 0, 0), 0.045)
	b.box(Vector3(0, 3.1, 0.25), Vector3(0.08, 0.08, 0.6), Pal.CHARCOAL, 0.02)
	b.cyl(Vector3(0, 2.92, 0.55), 0.2, 0.18, Pal.CHARCOAL, 8, 0.02, Color(0, 0, 0, 0), 0.08)


static func _bench(b: MeshBuilder) -> void:
	for x in [-0.6, 0.6]:
		b.block(Vector3(x, 0, 0), Vector3(0.08, 0.42, 0.45), Pal.CHARCOAL, 0.015)
	for z in [-0.12, 0.0, 0.12]:
		b.box(Vector3(0, 0.44, z), Vector3(1.5, 0.05, 0.1), Pal.OAK, 0.012)
	for y in [0.6, 0.75]:
		b.box(Vector3(0, y, -0.2), Vector3(1.5, 0.08, 0.04), Pal.OAK, 0.012)


static func _hydrant(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.14, 0.08, Pal.FIRE_RED.darkened(0.1), 8)
	b.cyl(Vector3(0, 0.08, 0), 0.1, 0.4, Pal.FIRE_RED, 8, 0.02)
	b.cyl(Vector3(0, 0.48, 0), 0.12, 0.1, Pal.FIRE_RED.darkened(0.1), 8, 0.03, Color(0, 0, 0, 0), 0.04)
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * 0.13, 0.3, 0), Vector3(0.08, 0.08, 0.08), Pal.FIRE_RED.darkened(0.1), 0.02)


static func _for_sale_sign(b: MeshBuilder) -> void:
	for x in [-0.35, 0.35]:
		b.block(Vector3(x, 0, 0), Vector3(0.06, 1.1, 0.06), Pal.WALNUT, 0.012)
	b.box(Vector3(0, 0.95, 0.04), Vector3(0.95, 0.5, 0.04), Pal.CREAM, 0.02)
	b.box(Vector3(0, 1.1, 0.065), Vector3(0.8, 0.12, 0.008), Pal.DINER_RED)
	b.box(Vector3(0, 0.88, 0.065), Vector3(0.5, 0.08, 0.008), Pal.UI_INK)


static func _cone(b: MeshBuilder) -> void:
	var o := Color("f28c28")
	b.block(Vector3.ZERO, Vector3(0.34, 0.04, 0.34), o.darkened(0.15), 0.01)
	b.cyl(Vector3(0, 0.04, 0), 0.13, 0.5, o, 8, 0.0, Color(0, 0, 0, 0), 0.03)
	b.cyl(Vector3(0, 0.22, 0), 0.094, 0.08, Pal.CREAM, 8, 0.0, Color(0, 0, 0, 0), 0.082)


static func _pallet(b: MeshBuilder) -> void:
	var c := Pal.CRATE.darkened(0.08)
	for z in [-0.4, 0.0, 0.4]:
		b.block(Vector3(0, 0, z), Vector3(0.95, 0.07, 0.1), c.darkened(0.1), 0.01)
	for x in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		b.block(Vector3(x, 0.07, 0), Vector3(0.13, 0.03, 0.95), c, 0.008)


static func _mailbox(b: MeshBuilder) -> void:
	b.block(Vector3.ZERO, Vector3(0.08, 0.9, 0.08), Pal.CHARCOAL, 0.01)
	b.block(Vector3(0, 0.9, 0), Vector3(0.3, 0.28, 0.45), Color("3e6fa8"), 0.06)


static func _street_planter(b: MeshBuilder) -> void:
	b.block(Vector3.ZERO, Vector3(1.4, 0.4, 0.5), Pal.CONCRETE, 0.04)
	b.block(Vector3(0, 0.4, 0), Vector3(1.3, 0.02, 0.4), Pal.DIRT.darkened(0.3))
	for x in [-0.4, 0.0, 0.4]:
		b.sphere(Vector3(x, 0.55, 0), Vector3(0.28, 0.22, 0.22), Pal.LEAF_LIGHT, 1, Color(0, 0, 0, 0), 0.15, int(x * 10) + 20)


static func _dumpster(b: MeshBuilder) -> void:
	var c := Color("3f6f5a")
	b.block(Vector3.ZERO, Vector3(1.8, 1.05, 1.1), c, 0.05)
	b.push_at(Vector3(0, 1.05, -0.55), 0.0, Vector3.ONE, -0.12)
	b.block(Vector3(0, 0, 0.55), Vector3(1.85, 0.06, 1.12), Pal.RUBBER, 0.02)
	b.pop()
	b.box(Vector3(0, 0.6, 0.56), Vector3(1.0, 0.18, 0.02), Pal.CREAM)
	for x in [-0.7, 0.7]:
		b.cyl(Vector3(x, -0.0, 0.4), 0.07, 0.1, Pal.RUBBER, 6)


static func _awning(b: MeshBuilder) -> void:
	# 1 m wide striped awning segment; projects toward +Z.
	for k in 4:
		var col := Pal.DINER_RED if k % 2 == 0 else Pal.CREAM
		b.push_at(Vector3(-0.375 + k * 0.25, 0, 0.35), 0.0, Vector3.ONE, 0.45)
		b.box(Vector3.ZERO, Vector3(0.25, 0.04, 0.78), col, 0.006)
		b.pop()
	for k in 4:
		var col2 := Pal.DINER_RED if k % 2 == 0 else Pal.CREAM
		b.box(Vector3(-0.375 + k * 0.25, -0.24, 0.7), Vector3(0.24, 0.16, 0.025), col2, 0.006)


# -----------------------------------------------------------------------------
# Mess decals and feedback markers
# -----------------------------------------------------------------------------

static func _mess_spill(b: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var pts := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		var r := 0.34 * rng.randf_range(0.7, 1.15)
		pts.push_back(Vector2(cos(a) * r, sin(a) * r))
	b.extrude(pts, 0.0, 0.012, Color("8fc4d6"))
	b.cyl(Vector3(0.22, 0.0, 0.18), 0.08, 0.012, Color("8fc4d6"), 7)


static func _mess_trash(b: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for k in 5:
		var a := rng.randf() * TAU
		var rr := rng.randf() * 0.25
		b.push_at(Vector3(cos(a) * rr, 0.0, sin(a) * rr), rng.randf() * TAU)
		b.sphere(Vector3(0, 0.04, 0), Vector3(0.06, 0.04, 0.05), Pal.CREAM.darkened(rng.randf() * 0.15), 0, Color(0, 0, 0, 0), 0.2, k)
		b.pop()
	b.push_at(Vector3(0.1, 0, -0.1), 0.6)
	b.block(Vector3.ZERO, Vector3(0.18, 0.01, 0.12), Pal.CARDBOARD, 0.003)
	b.pop()


static func _ping_marker(b: MeshBuilder) -> void:
	b.push_at(Vector3(0, 0.0, 0), 0.0, Vector3.ONE, PI)
	b.cyl(Vector3.ZERO, 0.0, 0.25, Color(1, 1, 1), 4, 0.0, Color(0, 0, 0, 0), 0.14)
	b.pop()
	b.cyl(Vector3.ZERO, 0.14, 0.08, Color(1, 1, 1), 4, 0.02)


static func _ring(b: MeshBuilder) -> void:
	# Flat ring (outer 0.5, inner 0.4) for the player identity marker.
	var n := 20
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		b.face(PackedVector3Array([
			Vector3(cos(a0) * 0.4, 0, sin(a0) * 0.4), Vector3(cos(a0) * 0.5, 0, sin(a0) * 0.5),
			Vector3(cos(a1) * 0.5, 0, sin(a1) * 0.5), Vector3(cos(a1) * 0.4, 0, sin(a1) * 0.4),
		]), Color(1, 1, 1), Vector3.UP)


static func _puff(b: MeshBuilder) -> void:
	b.sphere(Vector3.ZERO, Vector3(0.12, 0.1, 0.12), Color(1, 1, 1), 1)
