class_name ModelsFood
## Food models. Food gets a little more detail and saturation than props: chunky
## readable silhouettes that survive the overhead camera. Cookable foods are
## modelled in pale tones so the cooking colour can be multiplied in per instance.

const BUN_CUT := Color("f3d9a6")
const COOK_BASE := Color("f4ece6")
const FRY_BASE := Color("fbf3dc")


static func build(key: StringName, b: MeshBuilder) -> bool:
	match key:
		&"bun": _bun(b)
		&"bun_bottom": _bun_bottom(b)
		&"bun_top": _bun_top(b)
		&"patty": _patty(b)
		&"lettuce_head": _lettuce_head(b)
		&"lettuce_chopped": _lettuce_chopped(b)
		&"tomato": _tomato(b)
		&"tomato_sliced": _tomato_sliced(b)
		&"potato": _potato(b)
		&"potato_cut": _potato_cut(b)
		&"coffee_beans": _coffee_beans(b)
		&"coffee_fill": _coffee_fill(b)
		&"cheese": _cheese(b)
		&"fry_boat": _fry_boat(b)
		&"salad_greens": _salad_greens(b)
		&"crumbs": _crumbs(b)
		&"milk": _milk(b)
		&"milk_fill": _fill(b, Color("f7f3ea"), Color("ffffff"))
		&"latte_fill": _latte_fill(b)
		&"beer_fill": _beer_fill(b)
		&"soda_fill": _soda_fill(b)
		&"croissant": _croissant(b)
		&"muffin": _muffin(b)
		&"jam": _jam(b)
		&"dough": _dough(b)
		&"sauce": _sauce_jar(b)
		&"pepperoni": _pepperoni(b)
		&"mushroom": _mushroom(b)
		&"mushroom_sliced": _mushroom_sliced(b)
		&"pizza_base": _pizza_base(b)
		&"pizza_sauce": _pizza_sauce(b)
		&"pizza_cheese": _pizza_cheese(b)
		&"pizza_pepperoni": _pizza_pepperoni(b)
		&"pizza_mushrooms": _pizza_mushrooms(b)
		&"wings": _wings(b)
		&"dip": _dip(b)
		&"soda_syrup": _soda_syrup(b)
		&"keg": _keg(b)
		_: return false
	return true


static func _bun_bottom(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.13, 0.045, Pal.BUN, 10, 0.014, BUN_CUT)


static func _dome(b: MeshBuilder, base: Vector3, r: float, h: float, col: Color, sides := 10) -> void:
	b.cyl(base, r, h * 0.35, col, sides, 0.0, Color(0, 0, 0, 0), r * 0.96)
	b.cyl(base + Vector3(0, h * 0.35, 0), r * 0.96, h * 0.35, col, sides, 0.0, Color(0, 0, 0, 0), r * 0.74)
	b.cyl(base + Vector3(0, h * 0.7, 0), r * 0.74, h * 0.3, col, sides, 0.0, Color(0, 0, 0, 0), r * 0.25)


static func _bun_top(b: MeshBuilder) -> void:
	_dome(b, Vector3.ZERO, 0.135, 0.09, Pal.BUN_TOP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for k in 7:
		var a := TAU * k / 7.0 + rng.randf() * 0.4
		var rr := rng.randf_range(0.03, 0.07)
		var p := Vector3(cos(a) * rr, 0.075 - rr * 0.35, sin(a) * rr)
		b.push_at(p, a)
		b.box(Vector3.ZERO, Vector3(0.022, 0.01, 0.012), Pal.SESAME, 0.003)
		b.pop()


static func _bun(b: MeshBuilder) -> void:
	_bun_bottom(b)
	b.push_at(Vector3(0, 0.05, 0))
	_bun_top(b)
	b.pop()


static func _patty(b: MeshBuilder) -> void:
	b.jitter = 0.004
	b.cyl(Vector3.ZERO, 0.12, 0.045, COOK_BASE, 9, 0.014)
	b.jitter = 0.0
	# Grill marks (darker stripes) read once the patty is cooked.
	for k in 3:
		var z := -0.05 + k * 0.05
		b.push_at(Vector3(0, 0.046, z), 0.5)
		b.box(Vector3.ZERO, Vector3(0.17, 0.004, 0.014), COOK_BASE.darkened(0.45))
		b.pop()


static func _lettuce_head(b: MeshBuilder) -> void:
	b.sphere(Vector3(0, 0.1, 0), Vector3(0.12, 0.1, 0.12), Pal.LETTUCE, 1, Pal.LETTUCE.lightened(0.1), 0.08, 7)
	for k in 5:
		var a := TAU * k / 5.0
		b.push_at(Vector3(cos(a) * 0.07, 0.05, sin(a) * 0.07), a, Vector3.ONE, 0.9 * cos(a), 0.9 * sin(a))
		b.wavy_disc(Vector3.ZERO, 0.08, 0.012, Pal.LETTUCE_DARK, 5, 0.25, 0.01, k)
		b.pop()


static func _lettuce_chopped(b: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 9:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(0.0, 0.09)
		var y := 0.01 + (0.03 if rr < 0.04 else 0.0) + rng.randf() * 0.02
		b.push_at(Vector3(cos(a) * rr, y, sin(a) * rr), rng.randf() * TAU, Vector3.ONE, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
		var col: Color = Pal.LETTUCE if k % 3 else Pal.LETTUCE_DARK
		b.wavy_disc(Vector3.ZERO, rng.randf_range(0.04, 0.06), 0.012, col.lightened(rng.randf() * 0.12), 4, 0.3, 0.008, k)
		b.pop()


static func _tomato(b: MeshBuilder) -> void:
	b.sphere(Vector3(0, 0.085, 0), Vector3(0.1, 0.085, 0.1), Pal.TOMATO, 1, Color(0, 0, 0, 0), 0.04, 3)
	for k in 5:
		var a := TAU * k / 5.0
		b.push_at(Vector3(cos(a) * 0.025, 0.168, sin(a) * 0.025), -a)
		b.box(Vector3.ZERO, Vector3(0.05, 0.012, 0.016), Pal.STEM, 0.004)
		b.pop()
	b.cyl(Vector3(0, 0.16, 0), 0.01, 0.035, Pal.STEM, 5)


static func _tomato_sliced(b: MeshBuilder) -> void:
	var offs := [Vector3(-0.045, 0.0, -0.01), Vector3(0.0, 0.012, 0.02), Vector3(0.05, 0.004, -0.015)]
	for k in 3:
		b.push_at(offs[k], k * 0.7, Vector3.ONE, 0.1 * (k - 1), 0.05)
		b.cyl(Vector3.ZERO, 0.072, 0.022, Pal.TOMATO, 9, 0.006, Pal.TOMATO_IN)
		# seed pockets
		for s in 3:
			var a := TAU * s / 3.0 + 0.4
			b.box(Vector3(cos(a) * 0.035, 0.023, sin(a) * 0.035), Vector3(0.022, 0.003, 0.016), Pal.TOMATO.lightened(0.35))
		b.pop()


static func _potato(b: MeshBuilder) -> void:
	b.sphere(Vector3(0, 0.07, 0), Vector3(0.115, 0.07, 0.085), Pal.POTATO, 1, Pal.POTATO.lightened(0.06), 0.12, 5)
	for k in 4:
		var a := TAU * k / 4.0 + 0.3
		b.box(Vector3(cos(a) * 0.08, 0.1, sin(a) * 0.055), Vector3(0.012, 0.006, 0.012), Pal.POTATO.darkened(0.35))


static func _potato_cut(b: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for layer in 3:
		var n := 5 - layer
		for k in n:
			var x := (k - (n - 1) * 0.5) * 0.034
			var yaw := rng.randf_range(-0.35, 0.35)
			b.push_at(Vector3(x, 0.014 + layer * 0.026, rng.randf_range(-0.02, 0.02)), yaw + (0.5 if layer == 1 else 0.0), Vector3.ONE, 0.0, rng.randf_range(-0.15, 0.15))
			b.box(Vector3.ZERO, Vector3(0.026, 0.026, rng.randf_range(0.13, 0.17)), FRY_BASE, 0.004)
			b.pop()


static func _coffee_beans(b: MeshBuilder) -> void:
	# Small burlap bag with a fold and beans on top.
	b.jitter = 0.006
	b.cyl(Vector3.ZERO, 0.12, 0.2, Pal.SACK, 8, 0.03, Color(0, 0, 0, 0), 0.105)
	b.jitter = 0.0
	b.cyl(Vector3(0, 0.19, 0), 0.112, 0.035, Pal.SACK.darkened(0.12), 8, 0.01)
	b.box(Vector3(0, 0.1, 0.112), Vector3(0.12, 0.08, 0.01), Pal.CREAM, 0.003)
	b.box(Vector3(0, 0.1, 0.118), Vector3(0.05, 0.05, 0.004), Pal.BEANS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 9:
		var a := rng.randf() * TAU
		var rr := rng.randf() * 0.07
		b.push_at(Vector3(cos(a) * rr, 0.215, sin(a) * rr), rng.randf() * TAU)
		b.sphere(Vector3.ZERO, Vector3(0.018, 0.011, 0.013), Pal.BEANS, 0)
		b.pop()


static func _coffee_fill(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.062, 0.006, COOK_BASE, 10, 0.0)
	b.cyl(Vector3(0.012, 0.006, -0.01), 0.025, 0.002, COOK_BASE.lightened(0.2), 7)


static func _cheese(b: MeshBuilder) -> void:
	b.push_at(Vector3.ZERO, PI / 4.0)
	b.box(Vector3(0, 0.008, 0), Vector3(0.2, 0.016, 0.2), Pal.CHEESE, 0.004)
	b.pop()


static func _fry_boat(b: MeshBuilder) -> void:
	var red := Color("d8473a")
	var white := Color("f5efe3")
	b.block(Vector3.ZERO, Vector3(0.2, 0.012, 0.13), white)
	for side in [-1.0, 1.0]:
		b.push_at(Vector3(0, 0.03, side * 0.07), 0.0, Vector3.ONE, side * 0.35)
		b.box(Vector3.ZERO, Vector3(0.2, 0.06, 0.01), red, 0.003)
		b.pop()
		b.push_at(Vector3(side * 0.105, 0.03, 0), PI / 2.0, Vector3.ONE, side * 0.35)
		b.box(Vector3.ZERO, Vector3(0.13, 0.06, 0.01), white, 0.003)
		b.pop()


static func _salad_greens(b: MeshBuilder) -> void:
	_lettuce_chopped(b)


static func _crumbs(b: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for k in 10:
		var a := rng.randf() * TAU
		var rr := rng.randf() * 0.35
		b.push_at(Vector3(cos(a) * rr, 0.0, sin(a) * rr), rng.randf() * TAU)
		b.block(Vector3.ZERO, Vector3(rng.randf_range(0.025, 0.05), 0.012, rng.randf_range(0.02, 0.04)), Pal.BUN.darkened(rng.randf() * 0.3), 0.004)
		b.pop()


# -----------------------------------------------------------------------------
# Coffee shop, pizza parlor and bar
# -----------------------------------------------------------------------------

static func _milk(b: MeshBuilder) -> void:
	b.block(Vector3.ZERO, Vector3(0.09, 0.15, 0.09), Color("f7f5ef"), 0.008)
	b.block(Vector3(0, 0.05, 0), Vector3(0.094, 0.05, 0.094), Color("5b8fd6"), 0.004)
	b.push_at(Vector3(0, 0.15, 0), 0.0, Vector3(1, 1, 1), 0.0, PI / 4.0)
	b.box(Vector3.ZERO, Vector3(0.05, 0.05, 0.09), Color("f7f5ef"), 0.004)
	b.pop()


## Drink surface for a mug (sits just above the mug's cap).
static func _fill(b: MeshBuilder, col: Color, top: Color) -> void:
	b.cyl(Vector3.ZERO, 0.062, 0.006, col, 10, 0.0, top)


static func _latte_fill(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.062, 0.006, Color("c99a6b"), 10)
	# Foam heart
	b.cyl(Vector3(-0.012, 0.006, -0.008), 0.018, 0.003, Color("fbf5ea"), 8)
	b.cyl(Vector3(0.012, 0.006, -0.008), 0.018, 0.003, Color("fbf5ea"), 8)
	b.cyl(Vector3(0, 0.006, 0.012), 0.014, 0.003, Color("fbf5ea"), 3, 0.0, Color(0, 0, 0, 0), 0.004, PI / 2.0)


static func _beer_fill(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.062, 0.006, Color("e2a034"), 10)
	# Foam head spilling a little over the rim
	b.cyl(Vector3(0, 0.006, 0), 0.068, 0.014, Color("fbf6e6"), 10, 0.005)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		b.sphere(Vector3(cos(a) * 0.04, 0.022, sin(a) * 0.04), Vector3(0.022, 0.012, 0.022), Color("fffaf0"))


static func _soda_fill(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.062, 0.006, Color("4a2418"), 10)
	for k in 3:
		var a := TAU * k / 3.0
		b.push_at(Vector3(cos(a) * 0.028, 0.008, sin(a) * 0.028), a)
		b.box(Vector3.ZERO, Vector3(0.026, 0.02, 0.026), Color(0.85, 0.95, 1.0), 0.004)
		b.pop()
	# Straw
	b.push_at(Vector3(0.02, 0.0, 0.0), 0.0, Vector3.ONE, 0.0, -0.25)
	b.cyl(Vector3.ZERO, 0.008, 0.14, Color("e8412f"), 6)
	b.pop()


static func _croissant(b: MeshBuilder) -> void:
	# A crescent of tapering puffs; pale so the oven colour shows.
	var col := Color("f2dcae")
	for k in 5:
		var t := (k - 2) / 2.0
		var a := t * 1.1
		var r := 0.042 - absf(t) * 0.012
		b.sphere(Vector3(sin(a) * 0.1, r * 0.9, -cos(a) * 0.05 + 0.04), Vector3(r * 1.2, r, r), col, 1, Color(0, 0, 0, 0), 0.0, k)


static func _muffin(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.06, 0.06, Color("e7e1d4"), 10, 0.0, Color(0, 0, 0, 0), 0.075)
	b.sphere(Vector3(0, 0.07, 0), Vector3(0.085, 0.05, 0.085), Color("b07440"), 1, Color(0, 0, 0, 0), 0.08, 7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 6:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(0.01, 0.05)
		b.sphere(Vector3(cos(a) * rr, 0.105, sin(a) * rr), Vector3(0.011, 0.011, 0.011), Color("3f3a7a"))


static func _jam(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.04, 0.07, Color("b3263a"), 8, 0.006)
	b.cyl(Vector3(0, 0.07, 0), 0.043, 0.02, Color("e9e2d2"), 8, 0.004)
	b.cyl(Vector3(0, 0.09, 0), 0.03, 0.004, Color("d24a3c"), 8)


static func _dough(b: MeshBuilder) -> void:
	b.sphere(Vector3(0, 0.05, 0), Vector3(0.085, 0.055, 0.085), Color("f6efd8"), 1, Color(0, 0, 0, 0), 0.05, 2)


static func _sauce_jar(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.045, 0.09, Color("c8302a"), 8, 0.006)
	b.cyl(Vector3(0, 0.03, 0), 0.047, 0.035, Color("f2e3c4"), 8)
	b.cyl(Vector3(0, 0.09, 0), 0.04, 0.018, Color("3f8f3a"), 8, 0.004)


static func _pepperoni(b: MeshBuilder) -> void:
	b.push_at(Vector3(0, 0.035, 0), 0.0, Vector3.ONE, 0.0, PI / 2.0)
	b.cyl(Vector3(0, -0.1, 0), 0.035, 0.2, Color("a8322a"), 8, 0.01)
	b.pop()
	for k in 3:
		b.cyl(Vector3(0.13, 0.0, -0.03 + k * 0.03), 0.032, 0.008, Color("c0453a"), 8)


static func _mushroom(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.025, 0.05, Color("efe6d4"), 7)
	b.sphere(Vector3(0, 0.06, 0), Vector3(0.065, 0.04, 0.065), Color("b8956a"), 1, Color(0, 0, 0, 0), 0.04, 4)


static func _mushroom_sliced(b: MeshBuilder) -> void:
	for k in 3:
		b.push_at(Vector3(-0.05 + k * 0.05, 0.0, 0.0), k * 0.5, Vector3.ONE, PI / 2.0)
		_mushroom_slice(b)
		b.pop()


static func _mushroom_slice(b: MeshBuilder) -> void:
	b.extrude(PackedVector2Array([Vector2(-0.03, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.02), Vector2(0.015, 0.035), Vector2(-0.015, 0.035), Vector2(-0.03, 0.02)]), 0.0, 0.008, Color("e3d2b3"))


## Pizza layers, all modelled pale/neutral so the dough's bake colour (passed
## through as a multiply) browns the whole pie together.
static func _pizza_base(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.19, 0.016, Color("f6efd8"), 14, 0.006)
	b.cyl(Vector3(0, 0.016, 0), 0.19, 0.006, Color("f6efd8"), 14, 0.004, Color(0, 0, 0, 0), 0.17)


static func _pizza_sauce(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.165, 0.004, Color("f2604a"), 14)


static func _pizza_cheese(b: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 9:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(0.0, 0.11)
		b.cyl(Vector3(cos(a) * rr, 0.0, sin(a) * rr), rng.randf_range(0.04, 0.06), 0.004 + k * 0.0006, Color("fff0b0"), 7)


static func _pizza_pepperoni(b: MeshBuilder) -> void:
	for k in 7:
		var a := TAU * k / 7.0 + 0.3
		var rr := 0.1 if k > 0 else 0.0
		b.cyl(Vector3(cos(a) * rr, 0.0, sin(a) * rr), 0.028, 0.006, Color("e2715e"), 9)


static func _pizza_mushrooms(b: MeshBuilder) -> void:
	for k in 6:
		var a := TAU * k / 6.0
		b.push_at(Vector3(cos(a) * 0.06, 0.0, sin(a) * 0.06), a)
		b.extrude(PackedVector2Array([Vector2(-0.022, -0.012), Vector2(0.022, -0.012), Vector2(0.018, 0.01), Vector2(0.0, 0.018), Vector2(-0.018, 0.01)]), 0.0, 0.006, Color("f0e4cc"))
		b.pop()


static func _wings(b: MeshBuilder) -> void:
	var offs := [Vector3(-0.05, 0.0, -0.02), Vector3(0.03, 0.0, -0.04), Vector3(0.0, 0.0, 0.04), Vector3(0.06, 0.03, 0.01), Vector3(-0.03, 0.035, 0.02)]
	for k in offs.size():
		b.push_at(offs[k] + Vector3(0, 0.03, 0), k * 1.1)
		b.sphere(Vector3.ZERO, Vector3(0.05, 0.028, 0.032), COOK_BASE, 1, Color(0, 0, 0, 0), 0.0, k)
		b.sphere(Vector3(0.05, 0.0, 0.0), Vector3(0.022, 0.018, 0.02), COOK_BASE, 0)
		b.pop()


static func _dip(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.04, 0.035, Color("f0ece4"), 9, 0.004, Color(0, 0, 0, 0), 0.046)
	b.cyl(Vector3(0, 0.035, 0), 0.04, 0.005, Color("f7f2df"), 9, 0.0, Color("e9e4c8"))


static func _soda_syrup(b: MeshBuilder) -> void:
	b.block(Vector3.ZERO, Vector3(0.16, 0.13, 0.11), Color("8a3a2a"), 0.008)
	b.block(Vector3(0, 0.03, 0.056), Vector3(0.12, 0.06, 0.008), Color("f2e3c4"))
	b.cyl(Vector3(0.05, 0.13, 0.0), 0.012, 0.02, Color("2c2e33"), 6)


static func _keg(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.09, 0.22, Color("c3cacd"), 10, 0.01)
	for y in [0.03, 0.19]:
		b.cyl(Vector3(0, y, 0), 0.094, 0.018, Color("858e93"), 10)
	b.cyl(Vector3(0, 0.22, 0), 0.025, 0.02, Color("3d4147"), 6)
