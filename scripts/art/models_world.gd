class_name ModelsWorld
## Models for the train and space station themes: scenery, platform parts,
## market stalls, hydroponic planters, the food printer and space props.

static func build(key: StringName, b: MeshBuilder) -> bool:
	match key:
		# Train
		&"market_stall": _market_stall(b)
		&"coach_seat": _coach_seat(b)
		&"gangway": _gangway(b)
		&"telegraph_pole": _telegraph_pole(b)
		&"rail_sleeper": _rail_sleeper(b)
		&"long_sleeper": _long_sleeper(b)
		&"hill": _hill(b)
		&"fence_post": _fence_post(b)
		&"platform_slab": _platform_slab(b)
		&"station_sign": _station_sign(b)
		&"passenger_car": _passenger_car(b)
		&"locomotive": _locomotive(b)
		&"bogie": _bogie(b)
		&"loco_wheel": _loco_wheel(b)
		&"coupling_rod": _coupling_rod(b)
		&"train_wheel": _train_wheel(b)
		&"grass_tuft": _grass_tuft(b)
		&"hay_bale": _hay_bale(b)
		# Space
		&"hydro_planter": _hydro_planter(b)
		&"sprout": _sprout(b)
		&"food_printer": _food_printer(b)
		&"shuttle": _shuttle(b)
		&"solar_panel": _solar_panel(b)
		&"antenna_mast": _antenna_mast(b)
		&"hull_greeble": _hull_greeble(b)
		_: return false
	return true


# -----------------------------------------------------------------------------
# Train
# -----------------------------------------------------------------------------

## Faces +Z: a wooden counter under a striped awning on four posts.
static func _market_stall(b: MeshBuilder) -> void:
	var wood := Color("9a6a42")
	b.block(Vector3(0, 0, -0.05), Vector3(0.9, 0.82, 0.6), wood, 0.03)
	b.block(Vector3(0, 0.82, -0.05), Vector3(0.96, 0.05, 0.66), wood.lightened(0.15), 0.015)
	b.block(Vector3(0, 0.25, 0.26), Vector3(0.86, 0.4, 0.02), Color("f2e3c4"), 0.006)
	for x in [-0.42, 0.42]:
		for z in [-0.32, 0.3]:
			b.block(Vector3(x, 0, z), Vector3(0.06, 2.0 if z < 0.0 else 1.85, 0.06), wood.darkened(0.15), 0.01)
	# Striped awning, sloping down to the front.
	for i in 6:
		var col := Color("d9483b") if i % 2 == 0 else Color("f7f1e3")
		b.push_at(Vector3(-0.45 + 0.075 + i * 0.15, 1.97, 0.0), 0.0, Vector3.ONE, 0.25)
		b.box(Vector3.ZERO, Vector3(0.15, 0.04, 0.82), col, 0.008)
		b.pop()
	for i in 6:
		var col2 := Color("d9483b") if i % 2 == 0 else Color("f7f1e3")
		b.block(Vector3(-0.45 + 0.075 + i * 0.15, 1.72, 0.41), Vector3(0.15, 0.14, 0.02), col2)


static func _coach_seat(b: MeshBuilder) -> void:
	var cloth := Color("2f5d6a")
	b.block(Vector3(0, 0, 0), Vector3(0.7, 0.42, 0.52), Color("4a3a30"), 0.02)
	b.block(Vector3(0, 0.42, 0.02), Vector3(0.72, 0.08, 0.5), cloth, 0.03)
	b.block(Vector3(0, 0.42, -0.23), Vector3(0.72, 0.62, 0.1), cloth, 0.03)
	b.block(Vector3(0, 1.02, -0.23), Vector3(0.74, 0.06, 0.12), Color("efe2c6"), 0.02)


static func _gangway(b: MeshBuilder) -> void:
	for k in 7:
		var w := 0.42 if k % 2 == 0 else 0.36
		b.block(Vector3(0, k * 0.33, 0), Vector3(w, 0.33, 0.3), Color("2a2a2c").lightened(0.06 * (k % 2)), 0.02)


static func _telegraph_pole(b: MeshBuilder) -> void:
	var wood := Color("6e5038")
	b.cyl(Vector3.ZERO, 0.07, 3.3, wood, 6, 0.0, Color(0, 0, 0, 0), 0.055)
	b.box(Vector3(0, 3.0, 0), Vector3(0.9, 0.08, 0.08), wood, 0.01)
	for x in [-0.36, -0.12, 0.12, 0.36]:
		b.cyl(Vector3(x, 3.04, 0), 0.03, 0.08, Color("e8e2d0"), 6)


static func _rail_sleeper(b: MeshBuilder) -> void:
	b.block(Vector3.ZERO, Vector3(0.22, 0.015, 1.9), Color("5a4636"))


static func _long_sleeper(b: MeshBuilder) -> void:
	b.block(Vector3.ZERO, Vector3(0.24, 0.015, 6.9), Color("5a4636"))


static func _hill(b: MeshBuilder) -> void:
	b.sphere(Vector3(0, 0.0, 0), Vector3(1.8, 1.0, 0.9), Pal.GRASS_DARK, 1, Pal.GRASS, 0.08, 11)
	b.sphere(Vector3(1.0, 0.0, 0.2), Vector3(1.1, 0.7, 0.7), Pal.GRASS_DARK.darkened(0.05), 1, Pal.GRASS, 0.08, 12)


static func _fence_post(b: MeshBuilder) -> void:
	var wood := Color("8a6a4a")
	b.block(Vector3.ZERO, Vector3(0.08, 0.7, 0.08), wood, 0.01)
	b.block(Vector3(0.75, 0.48, 0), Vector3(1.5, 0.06, 0.04), wood.lightened(0.1))
	b.block(Vector3(0.75, 0.24, 0), Vector3(1.5, 0.06, 0.04), wood.lightened(0.1))


## The train's track bed is this far below the floor; its platform is a
## raised slab up to the doors.
const TRAIN_GROUND := -0.95
const LIVERY := Color("2f5d50")
const CREAM := Color("efe2c6")


## One metre of station platform (3 m deep, centred), level with the train
## floor, with the yellow safety line along the train side and a railing
## along the back edge.
static func _platform_slab(b: MeshBuilder) -> void:
	b.block(Vector3(0, TRAIN_GROUND, 0), Vector3(0.996, -TRAIN_GROUND, 2.98), Color("bdb7ab"), 0.004)
	b.block(Vector3(0, TRAIN_GROUND, 1.47), Vector3(0.996, -TRAIN_GROUND - 0.06, 0.06), Color("a9a397"))
	b.block(Vector3(0, 0.0, -1.2), Vector3(0.996, 0.004, 0.18), Color("f2c230"))
	b.block(Vector3(0, 0.0, -1.47), Vector3(0.996, 0.004, 0.05), Color("8f8a80"))
	b.block(Vector3(-0.45, 0.0, 1.38), Vector3(0.06, 0.95, 0.06), Color("2f3a36"), 0.008)
	b.block(Vector3(0, 0.88, 1.38), Vector3(1.0, 0.06, 0.06), Color("2f3a36"), 0.01)
	b.block(Vector3(0, 0.45, 1.38), Vector3(1.0, 0.04, 0.04), Color("2f3a36"))


static func _station_sign(b: MeshBuilder) -> void:
	for x in [-0.9, 0.9]:
		b.block(Vector3(x, 0, 0), Vector3(0.08, 1.95, 0.08), Pal.CHARCOAL, 0.01)
	b.box(Vector3(0, 1.62, 0), Vector3(2.0, 0.42, 0.1), Color("2f5d50"), 0.02)
	b.box(Vector3(0, 1.62, 0.03), Vector3(1.88, 0.32, 0.06), Color("f7f1e3"), 0.01)


## A wheel seen from the side (axis along Z), with spokes so the spin shows.
static func _train_wheel(b: MeshBuilder) -> void:
	b.push_at(Vector3.ZERO, 0.0, Vector3.ONE, PI * 0.5)
	b.cyl(Vector3(0, -0.04, 0), 0.24, 0.08, Color("2a2a2c"), 12, 0.01)
	b.cyl(Vector3(0, -0.05, 0), 0.08, 0.1, Color("8c8f94"), 8)
	b.pop()
	for k in 3:
		b.push_at(Vector3(0, 0, 0.045), 0.0, Vector3.ONE, 0.0, k * PI / 3.0)
		b.box(Vector3.ZERO, Vector3(0.4, 0.04, 0.02), Color("b33a2e"))
		b.pop()


static func _grass_tuft(b: MeshBuilder) -> void:
	for k in 4:
		var a := k * 1.7
		b.push_at(Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), a, Vector3.ONE, 0.0, 0.25 * (k % 2 * 2 - 1))
		b.box(Vector3(0, 0.12, 0), Vector3(0.05, 0.24, 0.02), Pal.GRASS_DARK.lightened(0.05 * k))
		b.pop()


static func _hay_bale(b: MeshBuilder) -> void:
	b.push_at(Vector3(0, 0.32, 0), 0.0, Vector3.ONE, PI * 0.5)
	b.cyl(Vector3(0, -0.35, 0), 0.32, 0.7, Color("d9b95a"), 10, 0.04)
	b.cyl(Vector3(0, -0.36, 0), 0.22, 0.72, Color("c9a44a"), 10)
	b.pop()



# -----------------------------------------------------------------------------
# Space
# -----------------------------------------------------------------------------

## A long grow tray on a white cabinet, with a grow-light bar above.
static func _hydro_planter(b: MeshBuilder) -> void:
	var white := Color("e9edf2")
	b.block(Vector3(0, 0, 0), Vector3(0.94, 0.62, 0.74), white, 0.03)
	b.block(Vector3(0, 0.62, 0), Vector3(0.96, 0.1, 0.76), Color("5d6675"), 0.015)
	b.block(Vector3(0, 0.72, 0), Vector3(0.88, 0.02, 0.66), Color("3b2e26"))
	b.block(Vector3(0, 0.3, 0.375), Vector3(0.7, 0.06, 0.02), Color("6fd3e0"))
	for x in [-0.44, 0.44]:
		b.block(Vector3(x, 0.72, -0.33), Vector3(0.04, 0.9, 0.04), Color("aeb6c2"), 0.008)
	b.block(Vector3(0, 1.58, -0.2), Vector3(0.92, 0.05, 0.3), Color("aeb6c2"), 0.01)
	b.block(Vector3(0, 1.555, -0.2), Vector3(0.84, 0.025, 0.2), Color("e97ae0"))


static func _sprout(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.012, 0.16, Color("5f9a3c"), 5)
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		b.push_at(Vector3(cos(a) * 0.05, 0.12 + k * 0.02, sin(a) * 0.05), -a, Vector3.ONE, 0.0, 0.5)
		b.box(Vector3.ZERO, Vector3(0.11, 0.012, 0.06), Pal.LEAF.lightened(0.05 * (k % 2)))
		b.pop()


## Faces +Z: a white cabinet with a glass print chamber and an output tray.
static func _food_printer(b: MeshBuilder) -> void:
	var white := Color("eef1f5")
	b.block(Vector3(0, 0, -0.08), Vector3(0.92, 1.5, 0.6), white, 0.04)
	b.block(Vector3(0, 0.5, 0.2), Vector3(0.8, 0.08, 0.2), Color("aeb6c2"), 0.01)
	b.block(Vector3(0, 0.58, 0.2), Vector3(0.74, 0.03, 0.16), Color("5d6675"))
	b.block(Vector3(0, 0.82, 0.215), Vector3(0.6, 0.5, 0.03), Color("6fd3e0").darkened(0.35), 0.01)
	# Inside the window: a gantry with the print head over a glowing plate.
	b.block(Vector3(0, 1.22, 0.235), Vector3(0.54, 0.035, 0.03), Pal.STEEL_DARK, 0.006)
	b.block(Vector3(0.08, 1.06, 0.24), Vector3(0.1, 0.16, 0.04), Color("f28a1c"), 0.01)
	b.cyl(Vector3(0.08, 1.0, 0.25), 0.012, 0.06, Pal.CHARCOAL, 6)
	b.block(Vector3(0, 0.84, 0.235), Vector3(0.46, 0.03, 0.03), Color("6fd3e0"))
	# Control screen
	b.block(Vector3(-0.32, 1.3, 0.215), Vector3(0.16, 0.12, 0.03), Color("2e3a5c"), 0.008)
	b.block(Vector3(-0.32, 1.33, 0.232), Vector3(0.11, 0.02, 0.01), Color("6af08a"))
	b.block(Vector3(0.3, 1.36, 0.215), Vector3(0.12, 0.06, 0.02), Color("6af08a"))
	b.cyl(Vector3(-0.28, 1.5, -0.1), 0.08, 0.12, Color("aeb6c2"), 8)


static func _shuttle(b: MeshBuilder) -> void:
	var white := Color("eef1f5")
	b.push_at(Vector3(0, 0.6, 0), 0.0, Vector3.ONE, PI * 0.5)
	b.cyl(Vector3(0, -1.4, 0), 0.62, 2.4, white, 10, 0.08)
	b.cyl(Vector3(0, 1.0, 0), 0.62, 0.6, white, 10, 0.06, Color(0, 0, 0, 0), 0.3)
	b.pop()
	b.block(Vector3(0, 0.62, 1.3), Vector3(0.6, 0.26, 0.05), Color("2e3a5c"), 0.01)
	for s in [-1.0, 1.0]:
		b.block(Vector3(s * 0.95, 0.45, -0.6), Vector3(0.7, 0.08, 1.0), Color("aeb6c2"), 0.02)
		b.block(Vector3(s * 1.25, 0.45, -0.95), Vector3(0.12, 0.5, 0.35), Pal.DINER_RED, 0.02)
	b.block(Vector3(0, 0.2, -1.5), Vector3(0.5, 0.5, 0.2), Color("5d6675"), 0.02)


static func _solar_panel(b: MeshBuilder) -> void:
	b.block(Vector3(0, 0.3, 0.9), Vector3(0.12, 0.12, 1.8), Color("aeb6c2"), 0.01)
	for k in 4:
		var x := -2.25 + k * 1.5
		b.block(Vector3(x, 0.3, 0.0), Vector3(1.4, 0.04, 1.2), Color("27345e"), 0.01)
		for j in 3:
			b.block(Vector3(x, 0.34, -0.4 + j * 0.4), Vector3(1.36, 0.004, 0.02), Color("6f86c9"))


static func _antenna_mast(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.06, 2.6, Color("aeb6c2"), 6)
	b.push_at(Vector3(0, 2.4, 0), 0.0, Vector3.ONE, -0.6)
	b.cyl(Vector3(0, 0, 0), 0.5, 0.12, Color("eef1f5"), 12, 0.02, Color(0, 0, 0, 0), 0.08)
	b.pop()
	b.sphere(Vector3(0, 2.7, 0), Vector3(0.06, 0.06, 0.06), Pal.DINER_RED)


static func _hull_greeble(b: MeshBuilder) -> void:
	b.block(Vector3(0, -0.4, 0), Vector3(3.0, 0.4, 0.5), Color("6f7883"), 0.03)
	for k in 4:
		b.block(Vector3(-1.2 + k * 0.8, -0.1, 0.1), Vector3(0.4, 0.14, 0.3), Color("aeb6c2"), 0.02)
	b.cyl(Vector3(1.6, -0.3, 0.0), 0.08, 0.3, Pal.DINER_RED, 6)



## A closed passenger car (7.8 m, centred on x; z 0..6), seen from the
## platform side: livery, cream window band with passengers at the windows,
## end doors and a curved roof. The train's other cars, which you can't enter.
static func _passenger_car(b: MeshBuilder) -> void:
	var l := 7.8
	b.block(Vector3(0, 0, 3.0), Vector3(l, 2.45, 6.0), LIVERY, 0.04)
	b.block(Vector3(0, 1.0, 6.0), Vector3(l - 0.2, 0.9, 0.04), CREAM)
	b.block(Vector3(0, 1.0, 0.0), Vector3(l - 0.2, 0.9, 0.04), CREAM)
	var skins := [Color("f2c9a0"), Color("c68a62"), Color("8d5a3c"), Color("f0d4b4")]
	var hair := [Color("3a2a20"), Color("c9a24a"), Color("1e1e22"), Color("8a4a2a")]
	for k in 6:
		var x := -2.6 + k * 1.04
		b.block(Vector3(x, 1.12, 6.02), Vector3(0.72, 0.66, 0.04), Color("2e3a4a"), 0.01)
		if k % 3 != 1:
			var c: Color = skins[(k * 7) % skins.size()]
			b.sphere(Vector3(x - 0.08, 1.42, 5.9), Vector3(0.14, 0.15, 0.14), c, 1)
			b.sphere(Vector3(x - 0.08, 1.52, 5.88), Vector3(0.15, 0.08, 0.15), hair[(k * 3) % hair.size()], 1)
	for x in [-l * 0.5 + 0.45, l * 0.5 - 0.45]:
		b.block(Vector3(x, 0.08, 6.02), Vector3(0.6, 2.05, 0.05), LIVERY.darkened(0.2), 0.01)
		b.block(Vector3(x, 1.25, 6.05), Vector3(0.32, 0.45, 0.03), Color("2e3a4a"))
	b.block(Vector3(0, 2.02, 6.02), Vector3(0.6, 0.18, 0.03), Color("c9a24a"))
	# Curved roof in three steps, with vents
	var roof := Color("4a4f55")
	b.block(Vector3(0, 2.45, 3.0), Vector3(l + 0.1, 0.24, 6.12), roof, 0.03)
	b.block(Vector3(0, 2.69, 3.0), Vector3(l, 0.18, 5.0), roof.lightened(0.06), 0.03)
	b.block(Vector3(0, 2.87, 3.0), Vector3(l - 0.1, 0.12, 3.4), roof.lightened(0.1), 0.03)
	for x in [-2.4, 0.0, 2.4]:
		b.block(Vector3(x, 2.99, 3.0), Vector3(0.5, 0.12, 0.5), roof.darkened(0.15), 0.02)


## A steam locomotive in the train's livery, cab at the back (x = 0), nose
## toward +x, 9.6 m long; driving wheels and the coupling rod are separate
## parts so they can turn.
static func _locomotive(b: MeshBuilder) -> void:
	var black := Color("1f2124")
	var red := Color("b3263a")
	var brass := Color("c9a24a")
	# Frame and running board
	b.block(Vector3(4.5, -0.3, 3.0), Vector3(9.0, 0.55, 4.6), black, 0.03)
	b.block(Vector3(4.6, 0.25, 3.0), Vector3(9.2, 0.08, 5.2), Color("2a2c30"), 0.02)
	# Boiler, banded in brass
	b.push_at(Vector3(2.5, 1.85, 3.0), 0.0, Vector3.ONE, 0.0, -PI * 0.5)
	b.cyl(Vector3.ZERO, 1.5, 5.0, LIVERY, 16, 0.04)
	b.pop()
	for x in [3.2, 4.8, 6.4]:
		b.push_at(Vector3(x, 1.85, 3.0), 0.0, Vector3.ONE, 0.0, -PI * 0.5)
		b.cyl(Vector3.ZERO, 1.53, 0.1, brass, 16)
		b.pop()
	# Smokebox and its round door
	b.push_at(Vector3(7.5, 1.85, 3.0), 0.0, Vector3.ONE, 0.0, -PI * 0.5)
	b.cyl(Vector3.ZERO, 1.56, 1.1, black, 16, 0.03)
	b.cyl(Vector3(0, 1.1, 0), 1.25, 0.08, Color("3a3d42"), 16, 0.02)
	b.cyl(Vector3(0, 1.18, 0), 0.2, 0.06, brass, 8)
	b.pop()
	# Chimney, domes and headlamp
	b.cyl(Vector3(7.95, 3.2, 3.0), 0.38, 0.85, black, 12, 0.02)
	b.cyl(Vector3(7.95, 4.0, 3.0), 0.5, 0.18, black, 12, 0.02)
	b.cyl(Vector3(5.4, 3.2, 3.0), 0.5, 0.42, brass, 12, 0.04)
	b.sphere(Vector3(5.4, 3.62, 3.0), Vector3(0.5, 0.28, 0.5), brass, 1)
	b.cyl(Vector3(3.9, 3.25, 3.0), 0.36, 0.3, LIVERY, 10, 0.03)
	b.sphere(Vector3(3.9, 3.55, 3.0), Vector3(0.36, 0.2, 0.36), LIVERY, 1)
	b.block(Vector3(8.75, 3.15, 3.0), Vector3(0.35, 0.35, 0.45), CREAM, 0.03)
	b.block(Vector3(8.93, 3.2, 3.0), Vector3(0.04, 0.22, 0.28), Color("fff2b0"))
	# Cab with windows and an overhanging roof
	b.block(Vector3(1.25, 0.3, 3.0), Vector3(2.5, 3.0, 5.0), LIVERY, 0.04)
	for z in [0.48, 5.52]:
		b.block(Vector3(1.4, 1.9, z), Vector3(1.0, 0.8, 0.04), Color("2e3a4a"))
	b.block(Vector3(1.0, 1.2, 5.53), Vector3(0.5, 0.3, 0.03), brass)
	b.block(Vector3(1.25, 3.3, 3.0), Vector3(2.9, 0.16, 5.4), black, 0.03)
	b.block(Vector3(1.25, 3.46, 3.0), Vector3(2.6, 0.1, 4.0), black, 0.03)
	# Buffer beam, buffers and the cowcatcher
	b.block(Vector3(9.05, -0.35, 3.0), Vector3(0.3, 0.7, 5.4), red, 0.03)
	for z in [1.2, 4.8]:
		b.push_at(Vector3(9.2, 0.0, z), 0.0, Vector3.ONE, 0.0, -PI * 0.5)
		b.cyl(Vector3.ZERO, 0.14, 0.4, black, 8)
		b.cyl(Vector3(0, 0.4, 0), 0.22, 0.06, Color("8c8f94"), 8)
		b.pop()
	for k in 6:
		var z2 := 0.9 + k * 0.84
		b.push_at(Vector3(9.25, -0.85, z2), 0.0, Vector3.ONE, 0.0, 0.6)
		b.box(Vector3(0, 0.35, 0), Vector3(0.12, 0.8, 0.5), red if k % 2 == 0 else black, 0.01)
		b.pop()
	# Cylinders (the pistons that drive the wheels)
	b.push_at(Vector3(7.4, 0.15, 5.45), 0.0, Vector3.ONE, 0.0, -PI * 0.5)
	b.cyl(Vector3.ZERO, 0.38, 1.1, black, 10, 0.03)
	b.pop()


## A bogie's side frame seen from the side: two axle boxes on springs.
static func _bogie(b: MeshBuilder) -> void:
	var dark := Color("26282c")
	b.block(Vector3(0, -0.12, 0), Vector3(2.1, 0.24, 0.1), dark, 0.02)
	for x in [-0.6, 0.6]:
		b.block(Vector3(x, -0.18, 0.04), Vector3(0.3, 0.32, 0.1), Color("3a3d42"), 0.02)
		b.block(Vector3(x, 0.08, 0.04), Vector3(0.22, 0.12, 0.12), Color("c9a24a"), 0.01)


## A big red spoked driving wheel (axis along Z).
static func _loco_wheel(b: MeshBuilder) -> void:
	var red := Color("b3263a")
	b.push_at(Vector3.ZERO, 0.0, Vector3.ONE, PI * 0.5)
	b.cyl(Vector3(0, -0.05, 0), 0.85, 0.1, Color("1f2124"), 16, 0.01)
	b.cyl(Vector3(0, -0.06, 0), 0.74, 0.12, red, 16)
	b.cyl(Vector3(0, -0.08, 0), 0.16, 0.16, Color("c9a24a"), 8)
	b.pop()
	for k in 5:
		b.push_at(Vector3(0, 0, 0.07), 0.0, Vector3.ONE, 0.0, k * PI / 5.0)
		b.box(Vector3.ZERO, Vector3(1.42, 0.07, 0.04), red.darkened(0.25))
		b.pop()
	b.block(Vector3(0.0, 0.3, 0.06), Vector3(0.36, 0.22, 0.08), red.darkened(0.25))


static func _coupling_rod(b: MeshBuilder) -> void:
	b.box(Vector3.ZERO, Vector3(3.8, 0.12, 0.06), Color("8c8f94"), 0.02)
	for x in [-1.8, 0.0, 1.8]:
		b.cyl(Vector3(x, -0.03, 0), 0.08, 0.1, Color("c9a24a"), 8)
