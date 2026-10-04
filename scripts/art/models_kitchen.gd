class_name ModelsKitchen
## Appliances and kitchen stations. Every station is a 1x1 m grid piece with its
## working face toward local +Z. Shapes are chunky and exaggerated: thick doors,
## oversized handles, big knobs, exaggerated burners.

const H := 0.8          # counter height (top surface)
const TOP_T := 0.07     # worktop thickness
const CAB := Color("e9dcc5")      # painted cabinet
const CAB_DOOR := Color("f1e6d2")
const HANDLE := Pal.WALNUT
const KNOB := Color("d24a3c")


static func build(key: StringName, b: MeshBuilder) -> bool:
	match key:
		&"counter": _counter(b)
		&"cutting_board": _cutting_board(b)
		&"grill": _grill(b)
		&"grill_glow": _grill_glow(b)
		&"fryer": _fryer(b)
		&"fryer_oil": _fryer_oil(b)
		&"coffee_machine": _coffee_machine(b)
		&"coffee_hopper_beans": _hopper_beans(b)
		&"fridge": _fridge(b)
		&"fridge_door": _fridge_door(b)
		&"sink": _sink(b)
		&"sink_water": _sink_water(b)
		&"dishwasher": _dishwasher(b)
		&"dishwasher_hood": _dishwasher_hood(b)
		&"trash_bin": _trash_bin(b)
		&"trash_lid": _trash_lid(b)
		&"plate_rack": _plate_rack(b)
		&"mug_rack": _mug_rack(b)
		&"shelf": _shelf(b)
		&"cold_shelf": _cold_shelf(b)
		&"extinguisher_station": _extinguisher_station(b)
		&"mop_station": _mop_station(b)
		&"conveyor": _conveyor(b)
		&"conveyor_cleat": _conveyor_cleat(b)
		&"grabber": _grabber(b)
		&"grabber_arm": _grabber_arm(b)
		&"auto_chopper": _auto_chopper(b)
		&"auto_chopper_blade": _auto_chopper_blade(b)
		&"pass_counter": _pass_counter(b)
		&"oven": _oven(b)
		&"oven_glow": _oven_glow(b)
		&"soda_fountain": _soda_fountain(b)
		&"syrup_level": _syrup_level(b)
		&"beer_tap": _beer_tap(b)
		&"keg_level": _keg_level(b)
		_: return false
	return true


# -----------------------------------------------------------------------------
# Shared pieces
# -----------------------------------------------------------------------------

static func cabinet(b: MeshBuilder, body := CAB, door := CAB_DOOR, doors := 2, h := H - TOP_T, w := 0.94, d := 0.88) -> void:
	b.block(Vector3(0, 0, -0.03), Vector3(w - 0.08, 0.09, d - 0.1), Pal.RUBBER, 0.01)
	b.block(Vector3(0, 0.08, 0), Vector3(w, h - 0.08, d), body, 0.03)
	if doors <= 0:
		return
	var dw := (w - 0.1) / doors
	var y0 := 0.13
	var dh := h - 0.08 - 0.1
	for k in doors:
		var x := -w * 0.5 + 0.05 + dw * (k + 0.5)
		b.box(Vector3(x, y0 + dh * 0.5, d * 0.5 + 0.015), Vector3(dw - 0.04, dh, 0.04), door, 0.015)
		var hx := x + (dw * 0.28 if k % 2 == 0 else -dw * 0.28)
		if doors == 1:
			hx = x
		b.box(Vector3(hx, y0 + dh - 0.09, d * 0.5 + 0.055), Vector3(0.05, 0.14, 0.045), HANDLE, 0.014)


static func worktop(b: MeshBuilder, col: Color, y := H - TOP_T, w := 1.0, d := 0.97) -> void:
	b.block(Vector3(0, y, 0), Vector3(w, TOP_T, d), col, 0.022)


static func steel_cabinet(b: MeshBuilder, doors := 2) -> void:
	cabinet(b, Pal.STEEL, Pal.STEEL.lightened(0.08), doors)


static func knob(b: MeshBuilder, pos: Vector3, col := KNOB, r := 0.05) -> void:
	b.push_at(pos, 0.0, Vector3.ONE, PI / 2.0)
	b.cyl(Vector3.ZERO, r, 0.045, Pal.STEEL_DARK, 8, 0.008)
	b.cyl(Vector3(0, 0.035, 0), r * 0.82, 0.04, col, 8, 0.012)
	b.box(Vector3(0, 0.078, -r * 0.4), Vector3(0.014, 0.008, r * 0.8), Pal.CREAM)
	b.pop()


# -----------------------------------------------------------------------------
# Stations
# -----------------------------------------------------------------------------

static func _counter(b: MeshBuilder) -> void:
	cabinet(b)
	worktop(b, Pal.BUTCHER)


static func _pass_counter(b: MeshBuilder) -> void:
	cabinet(b, Pal.OAK, Pal.OAK_LIGHT, 2)
	worktop(b, Pal.STEEL)
	# heat-lamp gantry
	for x in [-0.42, 0.42]:
		b.block(Vector3(x, H, -0.38), Vector3(0.05, 0.62, 0.05), Pal.STEEL_DARK, 0.01)
	b.box(Vector3(0, H + 0.64, -0.3), Vector3(0.96, 0.08, 0.22), Pal.STEEL_DARK, 0.02)
	b.box(Vector3(0, H + 0.595, -0.3), Vector3(0.8, 0.015, 0.14), Color("ffcf85"))


static func _cutting_board(b: MeshBuilder) -> void:
	cabinet(b)
	worktop(b, Pal.STEEL)
	# Oversized board with juice groove and a chunky knife.
	b.block(Vector3(0, H, 0.02), Vector3(0.72, 0.045, 0.56), Pal.OAK_LIGHT, 0.018)
	# Groove and inner face step up 5 mm each (thinner layers flicker)
	b.block(Vector3(0, H + 0.045, 0.02), Vector3(0.6, 0.005, 0.44), Pal.OAK)
	b.block(Vector3(0, H + 0.045, 0.02), Vector3(0.56, 0.01, 0.40), Pal.OAK_LIGHT.lightened(0.05))
	b.push_at(Vector3(0.3, H + 0.05, -0.27), 0.35)
	b.box(Vector3(0, 0.012, 0.0), Vector3(0.24, 0.012, 0.06), Pal.STEEL.lightened(0.1), 0.004)
	b.box(Vector3(-0.17, 0.016, 0.0), Vector3(0.12, 0.03, 0.04), Pal.WALNUT, 0.01)
	b.pop()


static func _grill(b: MeshBuilder) -> void:
	steel_cabinet(b, 2)
	# Body top frame
	b.block(Vector3(0, H - TOP_T, 0), Vector3(1.0, TOP_T, 0.97), Pal.STEEL_DARK, 0.02)
	# Dark griddle well
	b.block(Vector3(0, H - 0.01, -0.02), Vector3(0.84, 0.02, 0.74), Pal.CHARCOAL, 0.005)
	# Exaggerated grill bars
	for k in 6:
		var x := -0.35 + k * 0.14
		b.block(Vector3(x, H + 0.005, -0.02), Vector3(0.06, 0.035, 0.74), Pal.RUBBER.lightened(0.05), 0.012)
	# Backsplash with a vent slot
	b.block(Vector3(0, H, -0.45), Vector3(1.0, 0.28, 0.07), Pal.STEEL, 0.02)
	b.box(Vector3(0, H + 0.18, -0.41), Vector3(0.7, 0.04, 0.02), Pal.CHARCOAL)
	# Front control strip with big knobs
	b.push_at(Vector3(0, H - 0.1, 0.47), 0.0, Vector3.ONE, -0.35)
	b.box(Vector3.ZERO, Vector3(0.98, 0.14, 0.06), Pal.STEEL_DARK, 0.02)
	b.pop()
	for x in [-0.28, 0.28]:
		knob(b, Vector3(x, H - 0.1, 0.5), KNOB, 0.055)


static func _grill_glow(b: MeshBuilder) -> void:
	b.block(Vector3(0, H - 0.0, -0.02), Vector3(0.8, 0.006, 0.7), Color("ff8a3d"))


static func _fryer(b: MeshBuilder) -> void:
	steel_cabinet(b, 1)
	b.block(Vector3(0, H - TOP_T, 0), Vector3(1.0, TOP_T, 0.97), Pal.STEEL, 0.02)
	# Vat rim and deep well
	b.block(Vector3(0, H, -0.04), Vector3(0.78, 0.06, 0.7), Pal.STEEL_DARK, 0.025)
	b.block(Vector3(0, H + 0.02, -0.04), Vector3(0.64, 0.045, 0.56), Pal.CHARCOAL)
	# Basket (wire frame) with a long handle toward the front
	var bc := Pal.STEEL.lightened(0.15)
	for x in [-0.24, 0.24]:
		b.block(Vector3(x, H + 0.04, -0.04), Vector3(0.03, 0.06, 0.48), bc, 0.006)
	for z in [-0.26, 0.18]:
		b.block(Vector3(0, H + 0.04, z), Vector3(0.5, 0.06, 0.03), bc, 0.006)
	b.push_at(Vector3(0, H + 0.1, 0.32), 0.0, Vector3.ONE, 0.35)
	b.box(Vector3.ZERO, Vector3(0.05, 0.04, 0.34), bc, 0.01)
	b.box(Vector3(0, 0.0, 0.17), Vector3(0.08, 0.06, 0.12), Pal.RUBBER, 0.02)
	b.pop()
	# Mustard identity band + knobs
	b.box(Vector3(0, H - 0.12, 0.475), Vector3(0.96, 0.1, 0.02), Pal.MUSTARD, 0.01)
	knob(b, Vector3(0.36, H - 0.12, 0.49), Pal.CHARCOAL, 0.045)
	# Back flue
	b.block(Vector3(0, H, -0.46), Vector3(0.9, 0.36, 0.06), Pal.STEEL, 0.02)
	for k in 4:
		b.box(Vector3(-0.27 + k * 0.18, H + 0.26, -0.425), Vector3(0.12, 0.03, 0.02), Pal.CHARCOAL)


static func _fryer_oil(b: MeshBuilder) -> void:
	b.block(Vector3(0, H + 0.062, -0.04), Vector3(0.62, 0.01, 0.54), Color("d9a441"))   # 7 mm above the well


static func _coffee_machine(b: MeshBuilder) -> void:
	cabinet(b)
	worktop(b, Pal.BUTCHER)
	var body := Pal.CHARCOAL
	# Main machine body sits toward the back
	b.block(Vector3(0, H, -0.18), Vector3(0.78, 0.5, 0.5), body, 0.05)
	b.box(Vector3(0, H + 0.3, 0.075), Vector3(0.6, 0.22, 0.02), Pal.TEAL, 0.01)
	# Group head and big portafilter handle
	b.block(Vector3(0, H + 0.24, 0.12), Vector3(0.2, 0.08, 0.14), Pal.STEEL, 0.02)
	b.push_at(Vector3(0.12, H + 0.22, 0.24), 0.6)
	b.box(Vector3(0, 0, 0), Vector3(0.24, 0.05, 0.05), Pal.WALNUT, 0.018)
	b.pop()
	# Drip tray (mug goes here)
	b.block(Vector3(0, H, 0.17), Vector3(0.42, 0.04, 0.3), Pal.STEEL_DARK, 0.012)
	for k in 4:
		b.box(Vector3(0, H + 0.044, 0.07 + k * 0.065), Vector3(0.38, 0.008, 0.02), Pal.CHARCOAL)
	# Gauge and steam wand
	b.push_at(Vector3(-0.25, H + 0.4, 0.075), 0.0, Vector3.ONE, PI / 2)
	b.cyl(Vector3.ZERO, 0.055, 0.02, Pal.STEEL, 10)
	b.cyl(Vector3(0, 0.02, 0), 0.042, 0.004, Pal.CREAM, 10)
	b.pop()
	b.block(Vector3(0.3, H + 0.08, 0.1), Vector3(0.025, 0.2, 0.025), Pal.STEEL)
	# Bean hopper (transparent-looking frame; beans level is a separate mesh)
	b.cyl(Vector3(0, H + 0.5, -0.2), 0.13, 0.04, Pal.STEEL_DARK, 8)
	for k in 8:
		var a := TAU * k / 8.0
		b.block(Vector3(cos(a) * 0.15, H + 0.54, -0.2 + sin(a) * 0.15), Vector3(0.02, 0.22, 0.02), Pal.STEEL)
	b.cyl(Vector3(0, H + 0.76, -0.2), 0.165, 0.04, Pal.STEEL_DARK, 8, 0.01)


static func _hopper_beans(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.14, 1.0, Pal.BEANS, 8, 0.0, Pal.BEANS.lightened(0.15))


static func _fridge(b: MeshBuilder) -> void:
	var body := Color("eef1f0")
	var h := 1.9
	b.block(Vector3(0, 0, 0), Vector3(0.94, 0.08, 0.86), Pal.RUBBER, 0.01)
	# Shell (open front)
	b.block(Vector3(0, 0.06, -0.41), Vector3(0.96, h - 0.06, 0.1), body, 0.025)
	for x in [-0.45, 0.45]:
		b.block(Vector3(x, 0.06, 0), Vector3(0.06, h - 0.06, 0.92), body, 0.02)
	b.block(Vector3(0, 0.06, 0), Vector3(0.96, 0.1, 0.92), body, 0.02)
	b.block(Vector3(0, h - 0.24, 0), Vector3(0.96, 0.24, 0.92), body, 0.03)
	# Interior: cool blue back panel, wire shelves
	b.block(Vector3(0, 0.16, -0.355), Vector3(0.84, h - 0.42, 0.01), Pal.COLD_TILE)
	for y in [0.62, 1.18]:
		b.block(Vector3(0, y, -0.02), Vector3(0.84, 0.025, 0.7), Pal.STEEL, 0.006)
	# Top grille + brand plate
	for k in 5:
		b.box(Vector3(-0.3 + k * 0.15, h - 0.12, 0.465), Vector3(0.09, 0.05, 0.02), Pal.STEEL_DARK)
	b.box(Vector3(0, h - 0.03, 0.0), Vector3(0.7, 0.05, 0.6), body.darkened(0.06), 0.02)
	# Cold indicator light
	b.box(Vector3(0.36, h - 0.12, 0.47), Vector3(0.06, 0.05, 0.02), Color("6fd3f0"))


static func _fridge_door(b: MeshBuilder) -> void:
	# Door frame (glass pane is a separate transparent mesh). Hinge at x = -0.46.
	var body := Color("eef1f0")
	var h := 1.5
	var y0 := 0.16
	b.block(Vector3(0.46, y0, 0), Vector3(0.92, 0.08, 0.06), body, 0.02)
	b.block(Vector3(0.46, y0 + h - 0.08, 0), Vector3(0.92, 0.08, 0.06), body, 0.02)
	b.block(Vector3(0.04, y0, 0), Vector3(0.08, h, 0.06), body, 0.02)
	b.block(Vector3(0.88, y0, 0), Vector3(0.08, h, 0.06), body, 0.02)
	# Oversized handle
	b.block(Vector3(0.8, y0 + 0.4, 0.07), Vector3(0.06, 0.62, 0.06), Pal.STEEL_DARK, 0.02)
	for y in [y0 + 0.44, y0 + 0.98]:
		b.box(Vector3(0.8, y, 0.04), Vector3(0.05, 0.05, 0.06), Pal.STEEL_DARK, 0.01)
	# Hinges
	for y in [y0 + 0.15, y0 + h - 0.2]:
		b.box(Vector3(0.0, y, 0.0), Vector3(0.04, 0.12, 0.08), Pal.STEEL_DARK, 0.01)


static func _sink(b: MeshBuilder) -> void:
	steel_cabinet(b, 2)
	var y := H - TOP_T
	var top := Pal.STEEL
	# Worktop around a basin opening (basin on the left, drain board on the right)
	b.block(Vector3(0, y, -0.4), Vector3(1.0, TOP_T, 0.17), top, 0.015)
	b.block(Vector3(0, y, 0.4), Vector3(1.0, TOP_T, 0.17), top, 0.015)
	b.block(Vector3(-0.45, y, 0), Vector3(0.1, TOP_T, 0.64), top, 0.015)
	b.block(Vector3(0.21, y, 0), Vector3(0.58, TOP_T, 0.64), top, 0.015)
	# Basin
	b.block(Vector3(-0.2, y - 0.22, 0), Vector3(0.42, 0.24, 0.64), Pal.STEEL_DARK)
	b.block(Vector3(-0.2, y - 0.0, 0), Vector3(0.4, 0.005, 0.62), Pal.STEEL_DARK.darkened(0.2))
	# Drain board ridges
	for k in 5:
		b.box(Vector3(0.21, H + 0.006, -0.22 + k * 0.11), Vector3(0.5, 0.012, 0.03), top.lightened(0.08))
	# Gooseneck faucet (chunky)
	b.cyl(Vector3(-0.2, H, -0.4), 0.05, 0.06, Pal.STEEL_DARK, 8)
	b.block(Vector3(-0.2, H + 0.05, -0.4), Vector3(0.05, 0.4, 0.05), Pal.STEEL.lightened(0.1), 0.015)
	b.box(Vector3(-0.2, H + 0.45, -0.3), Vector3(0.05, 0.05, 0.25), Pal.STEEL.lightened(0.1), 0.015)
	b.box(Vector3(-0.2, H + 0.42, -0.19), Vector3(0.06, 0.06, 0.06), Pal.STEEL_DARK, 0.015)
	for x in [-0.33, -0.07]:
		b.cyl(Vector3(x, H, -0.4), 0.035, 0.06, Color("d24a3c") if x < -0.2 else Color("3e8fe8"), 6, 0.01)


static func _sink_water(b: MeshBuilder) -> void:
	b.block(Vector3(-0.2, H - TOP_T - 0.05, 0), Vector3(0.4, 0.006, 0.62), Color("b9e3ef"))


static func _dishwasher(b: MeshBuilder) -> void:
	# Commercial hood-type washer: steel base with a lifting hood.
	steel_cabinet(b, 1)
	b.block(Vector3(0, H - TOP_T, 0), Vector3(1.0, TOP_T, 0.97), Pal.STEEL, 0.02)
	# Wash bay floor with rack grid
	b.block(Vector3(0, H, 0), Vector3(0.8, 0.02, 0.8), Pal.STEEL_DARK)
	for k in 5:
		b.box(Vector3(-0.32 + k * 0.16, H + 0.03, 0), Vector3(0.025, 0.02, 0.76), Pal.STEEL.lightened(0.1))
		b.box(Vector3(0, H + 0.03, -0.32 + k * 0.16), Vector3(0.76, 0.02, 0.025), Pal.STEEL.lightened(0.1))
	# Control tower at the back
	b.block(Vector3(0.36, H, -0.42), Vector3(0.22, 0.95, 0.12), Pal.STEEL, 0.02)
	b.box(Vector3(0.36, H + 0.78, -0.355), Vector3(0.16, 0.14, 0.02), Pal.CHARCOAL, 0.01)


static func _dishwasher_hood(b: MeshBuilder) -> void:
	# Hood origin at the top of the bay; raises when open.
	var c := Pal.STEEL.lightened(0.04)
	b.block(Vector3(0, 0, -0.38), Vector3(0.84, 0.5, 0.06), c, 0.02)
	b.block(Vector3(0, 0, 0.38), Vector3(0.84, 0.5, 0.06), c, 0.02)
	b.block(Vector3(-0.41, 0, 0), Vector3(0.06, 0.5, 0.82), c, 0.02)
	b.block(Vector3(0.41, 0, 0), Vector3(0.06, 0.5, 0.82), c, 0.02)
	b.block(Vector3(0, 0.48, 0), Vector3(0.88, 0.07, 0.86), c, 0.025)
	# Big lifting handle across the front
	b.box(Vector3(0, 0.3, 0.46), Vector3(0.6, 0.05, 0.05), Pal.RUBBER, 0.015)
	for x in [-0.28, 0.28]:
		b.box(Vector3(x, 0.3, 0.43), Vector3(0.04, 0.04, 0.06), Pal.STEEL_DARK)


static func _trash_bin(b: MeshBuilder) -> void:
	var col := Color("3f6f5a")
	b.cyl(Vector3(0, 0, 0), 0.3, 0.06, Pal.RUBBER, 8, 0.01)
	b.cyl(Vector3(0, 0.04, 0), 0.29, 0.68, col, 8, 0.03, Color(0, 0, 0, 0), 0.32)
	b.cyl(Vector3(0, 0.665, 0), 0.335, 0.06, col.darkened(0.15), 8, 0.015)
	# Foot pedal
	b.block(Vector3(0, 0.0, 0.33), Vector3(0.22, 0.05, 0.12), Pal.STEEL_DARK, 0.015)
	# Recycling stripe
	b.cyl(Vector3(0, 0.3, 0), 0.305, 0.06, Pal.CREAM, 8)


static func _trash_lid(b: MeshBuilder) -> void:
	# Hinged at the back (z = -0.33)
	var col := Color("3f6f5a").lightened(0.06)
	b.push_at(Vector3(0, 0, 0.33))
	b.cyl(Vector3.ZERO, 0.33, 0.05, col, 8, 0.015, Color(0, 0, 0, 0), 0.3)
	b.box(Vector3(0, 0.07, 0.0), Vector3(0.18, 0.04, 0.06), Pal.RUBBER, 0.015)
	b.pop()


static func _plate_rack(b: MeshBuilder) -> void:
	cabinet(b, Pal.OAK, Pal.OAK_LIGHT, 2)
	worktop(b, Pal.BUTCHER)
	# Chunky wooden dowels holding the plate stack
	for a in 4:
		var ang := TAU * a / 4.0 + PI / 4.0
		b.cyl(Vector3(cos(ang) * 0.25, H, sin(ang) * 0.25), 0.025, 0.22, Pal.WALNUT, 6, 0.006)
	b.cyl(Vector3(0, H, 0), 0.24, 0.02, Pal.WALNUT.lightened(0.1), 10, 0.005)


static func _mug_rack(b: MeshBuilder) -> void:
	cabinet(b, Pal.OAK, Pal.OAK_LIGHT, 2)
	worktop(b, Pal.BUTCHER)
	b.block(Vector3(0, H, 0), Vector3(0.7, 0.03, 0.5), Pal.WALNUT, 0.01)
	b.block(Vector3(0, H + 0.03, -0.22), Vector3(0.7, 0.4, 0.04), Pal.WALNUT.lightened(0.05), 0.012)
	for k in 3:
		b.box(Vector3(-0.22 + k * 0.22, H + 0.36, -0.17), Vector3(0.03, 0.03, 0.08), Pal.STEEL_DARK, 0.006)


static func _shelf(b: MeshBuilder) -> void:
	var post := Pal.WALNUT
	var plank := Pal.OAK
	for x in [-0.44, 0.44]:
		for z in [-0.4, 0.4]:
			b.block(Vector3(x, 0, z), Vector3(0.07, 0.78, 0.07), post, 0.012)
	b.block(Vector3(0, 0.1, 0), Vector3(0.96, 0.05, 0.86), plank, 0.012)
	b.block(Vector3(0, 0.66, 0), Vector3(0.98, 0.07, 0.9), plank.lightened(0.05), 0.016)
	# Back rail and label strip (label colour is set per stored crate)
	b.block(Vector3(0, 0.73, -0.42), Vector3(0.96, 0.06, 0.04), post, 0.01)
	# Spare stuff on the bottom level for clutter
	b.block(Vector3(-0.22, 0.15, 0.05), Vector3(0.36, 0.22, 0.42), Pal.CARDBOARD, 0.015)
	b.block(Vector3(0.22, 0.15, -0.05), Vector3(0.3, 0.16, 0.34), Pal.CARDBOARD.darkened(0.1), 0.015)
	b.box(Vector3(0.22, 0.32, -0.05), Vector3(0.12, 0.01, 0.34), Pal.CREAM)


static func _cold_shelf(b: MeshBuilder) -> void:
	var post := Pal.STEEL_DARK
	for x in [-0.44, 0.44]:
		for z in [-0.4, 0.4]:
			b.block(Vector3(x, 0, z), Vector3(0.06, 0.78, 0.06), post, 0.01)
	for y in [0.1, 0.36]:
		b.block(Vector3(0, y, 0), Vector3(0.94, 0.03, 0.84), Pal.STEEL, 0.008)
	b.block(Vector3(0, 0.66, 0), Vector3(0.96, 0.06, 0.88), Pal.STEEL.lightened(0.06), 0.014)


static func _extinguisher_station(b: MeshBuilder) -> void:
	b.block(Vector3(0, 0, -0.1), Vector3(0.5, 0.06, 0.5), Pal.CHARCOAL, 0.015)
	b.block(Vector3(0, 0.06, -0.3), Vector3(0.12, 1.5, 0.12), Pal.FIRE_RED, 0.02)
	b.block(Vector3(0, 1.5, -0.3), Vector3(0.5, 0.3, 0.08), Pal.FIRE_RED, 0.02)
	b.box(Vector3(0, 1.66, -0.255), Vector3(0.36, 0.14, 0.02), Pal.CREAM, 0.005)
	b.box(Vector3(0, 1.66, -0.24), Vector3(0.1, 0.1, 0.01), Pal.FIRE_RED)
	# Cradle the extinguisher sits in
	b.block(Vector3(0, 0.06, -0.12), Vector3(0.3, 0.08, 0.24), Pal.STEEL_DARK, 0.02)


static func _mop_station(b: MeshBuilder) -> void:
	var yellow := Color("f2c230")
	b.block(Vector3(0, 0, 0), Vector3(0.6, 0.06, 0.45), Pal.CHARCOAL, 0.015)
	for x in [-0.22, 0.22]:
		for z in [-0.15, 0.15]:
			b.cyl(Vector3(x, 0.0, z), 0.04, 0.05, Pal.RUBBER, 6)
	b.block(Vector3(0, 0.05, 0), Vector3(0.56, 0.36, 0.42), yellow, 0.04)
	b.block(Vector3(0, 0.38, 0), Vector3(0.5, 0.02, 0.36), Color("8fb8c6"))
	# Wringer
	b.block(Vector3(0.18, 0.4, 0), Vector3(0.2, 0.2, 0.36), yellow.darkened(0.1), 0.03)
	b.box(Vector3(0.3, 0.62, 0), Vector3(0.05, 0.05, 0.3), Pal.RUBBER, 0.015)


static func _conveyor(b: MeshBuilder) -> void:
	var frame := Pal.STEEL_DARK
	var top := 0.72
	for x in [-0.36, 0.36]:
		for z in [-0.4, 0.4]:
			b.block(Vector3(x, 0, z), Vector3(0.07, top - 0.06, 0.07), frame, 0.012)
	for x in [-0.45, 0.45]:
		b.block(Vector3(x, top - 0.14, 0), Vector3(0.07, 0.18, 1.0), Pal.MUSTARD, 0.02)
	b.block(Vector3(0, top - 0.06, 0), Vector3(0.82, 0.06, 1.0), Pal.RUBBER)
	# Direction chevrons on the side rails (pointing +Z = output)
	for x in [-0.49, 0.49]:
		for k in 2:
			var z := -0.2 + k * 0.4
			b.push_at(Vector3(x, top - 0.05, z), 0.0)
			b.box(Vector3(0, 0, -0.03), Vector3(0.01, 0.04, 0.12), Pal.CHARCOAL)
			b.pop()
	b.block(Vector3(0, 0.12, 0), Vector3(0.7, 0.03, 0.8), frame)


static func _conveyor_cleat(b: MeshBuilder) -> void:
	b.box(Vector3(0, 0.01, 0), Vector3(0.8, 0.02, 0.06), Pal.CHARCOAL.lightened(0.08))


static func _grabber(b: MeshBuilder) -> void:
	b.block(Vector3(0, 0, 0), Vector3(0.7, 0.08, 0.7), Pal.CHARCOAL, 0.02)
	b.cyl(Vector3(0, 0.08, 0), 0.28, 0.5, Pal.MUSTARD, 8, 0.03)
	b.cyl(Vector3(0, 0.58, 0), 0.2, 0.08, Pal.CHARCOAL, 8, 0.02)
	# Hazard stripes
	for k in 4:
		var a := TAU * k / 4.0
		b.box(Vector3(cos(a) * 0.29, 0.2, sin(a) * 0.29), Vector3(0.06, 0.18, 0.06), Pal.CHARCOAL)


static func _grabber_arm(b: MeshBuilder) -> void:
	# Pivot at origin; the arm reaches toward -Z (pickup) when yaw = 0.
	b.cyl(Vector3.ZERO, 0.1, 0.12, Pal.STEEL_DARK, 8, 0.02)
	b.box(Vector3(0, 0.08, -0.3), Vector3(0.1, 0.08, 0.6), Pal.MUSTARD, 0.025)
	b.box(Vector3(0, 0.04, -0.6), Vector3(0.16, 0.08, 0.1), Pal.CHARCOAL, 0.02)
	for x in [-0.06, 0.06]:
		b.box(Vector3(x, -0.02, -0.62), Vector3(0.03, 0.1, 0.06), Pal.STEEL, 0.008)


static func _auto_chopper(b: MeshBuilder) -> void:
	steel_cabinet(b, 2)
	worktop(b, Pal.STEEL)
	b.block(Vector3(0, H, 0.05), Vector3(0.6, 0.03, 0.5), Pal.OAK_LIGHT, 0.01)
	# Gantry
	for x in [-0.36, 0.36]:
		b.block(Vector3(x, H, -0.3), Vector3(0.1, 0.62, 0.1), Pal.TEAL, 0.02)
	b.block(Vector3(0, H + 0.6, -0.3), Vector3(0.82, 0.14, 0.16), Pal.TEAL, 0.03)
	b.box(Vector3(0, H + 0.67, -0.215), Vector3(0.4, 0.06, 0.02), Pal.CREAM)
	b.box(Vector3(0.28, H + 0.67, -0.215), Vector3(0.06, 0.06, 0.02), Color("6fe39a"))


static func _auto_chopper_blade(b: MeshBuilder) -> void:
	b.box(Vector3(0, 0.12, 0), Vector3(0.08, 0.24, 0.08), Pal.STEEL_DARK, 0.015)
	b.box(Vector3(0, 0.0, 0.0), Vector3(0.5, 0.05, 0.12), Pal.STEEL.lightened(0.15), 0.01)


# -----------------------------------------------------------------------------
# Ovens and drink stations (pizza parlor, coffee shop, bar)
# -----------------------------------------------------------------------------

## Brick hearth oven: the pie (or pastry) bakes on the stone deck in front of
## a glowing mouth.
static func _oven(b: MeshBuilder) -> void:
	var brick := Pal.BRICK
	cabinet(b, Color("8a8378"), Color("9a9387"), 2)
	b.block(Vector3(0, H - TOP_T, 0), Vector3(1.0, TOP_T, 0.97), Color("cfc6b4"), 0.015)
	# Chamber and dome behind the deck
	b.block(Vector3(0, H, -0.27), Vector3(0.9, 0.36, 0.42), brick, 0.03)
	b.sphere(Vector3(0, H + 0.36, -0.27), Vector3(0.44, 0.22, 0.21), brick.darkened(0.05), 1, Color(0, 0, 0, 0), 0.02, 3)
	# Mouth (dark) and a stone arch around it
	b.block(Vector3(0, H + 0.04, -0.055), Vector3(0.46, 0.24, 0.012), Color("2a1d16"))
	b.block(Vector3(0, H + 0.28, -0.05), Vector3(0.56, 0.06, 0.03), Color("e7dcc6"), 0.01)
	# Chimney
	b.cyl(Vector3(0.24, H + 0.5, -0.32), 0.05, 0.4, Pal.STEEL_DARK, 8)
	# Thermometer dial on the front of the cabinet
	knob(b, Vector3(0.36, H - 0.14, 0.48), Pal.STEEL, 0.05)


static func _oven_glow(b: MeshBuilder) -> void:
	b.block(Vector3(0, H + 0.05, -0.04), Vector3(0.4, 0.2, 0.006), Color("ff8a3d"))


## A drinks fountain: a steel tower with three lit flavour panels (cola,
## lime, orange), a nozzle and push-lever under each, an ice-bin lid on top,
## a cup stack and a see-through syrup gauge on the side.
static func _soda_fountain(b: MeshBuilder) -> void:
	steel_cabinet(b, 2)
	worktop(b, Pal.STEEL.darkened(0.15))
	var steel := Color("c9cfd6")
	# Tower body and ice-bin lid
	b.block(Vector3(0, H, -0.24), Vector3(0.84, 0.66, 0.42), steel, 0.03)
	b.block(Vector3(0, H + 0.66, -0.24), Vector3(0.86, 0.06, 0.44), Pal.STEEL_DARK, 0.02)
	b.box(Vector3(0, H + 0.74, -0.1), Vector3(0.3, 0.03, 0.05), Pal.CHARCOAL, 0.01)
	# Flavour panels with a white wave and a bubble, like the drink brands
	var flavours := [Color("c8262c"), Color("4caf3a"), Color("f28a1c")]
	for k in 3:
		var x := -0.27 + k * 0.27
		var col: Color = flavours[k]
		b.block(Vector3(x, H + 0.3, -0.025), Vector3(0.24, 0.32, 0.03), col, 0.01)
		b.push_at(Vector3(x, H + 0.43, -0.008), 0.0, Vector3.ONE, 0.0, 0.35)
		b.box(Vector3.ZERO, Vector3(0.26, 0.035, 0.01), Color("fbf7ea"))
		b.pop()
		b.cyl(Vector3(x + 0.06, H + 0.52, -0.012), 0.025, 0.012, Color("fbf7ea"), 8, 0.0, Color(0, 0, 0, 0), -1.0, 0.0)
		# Nozzle and the lever a cup pushes
		b.block(Vector3(x, H + 0.26, -0.02), Vector3(0.1, 0.05, 0.08), Pal.STEEL_DARK, 0.01)
		b.cyl(Vector3(x, H + 0.21, 0.0), 0.022, 0.05, Pal.CHARCOAL, 6)
		b.block(Vector3(x, H + 0.11, -0.005), Vector3(0.07, 0.11, 0.02), col.darkened(0.15), 0.008)
	# Cup stack on the lid
	for k in 5:
		b.cyl(Vector3(0.3, H + 0.72 + k * 0.035, -0.32), 0.05 + k * 0.001, 0.05, Color("fbf7ea") if k % 2 == 0 else Color("c8262c"), 8)
	# Syrup gauge: a glass tube on the right side (the level is a separate part)
	b.block(Vector3(0.44, H + 0.06, -0.24), Vector3(0.07, 0.3, 0.07), Color("cfeaf2"), 0.01)
	b.block(Vector3(0.44, H + 0.36, -0.24), Vector3(0.08, 0.03, 0.08), Pal.STEEL_DARK, 0.008)
	# Drip tray
	b.block(Vector3(0, H, 0.17), Vector3(0.7, 0.04, 0.3), Pal.STEEL_DARK, 0.012)
	for k in 4:
		b.box(Vector3(0, H + 0.044, 0.07 + k * 0.065), Vector3(0.66, 0.008, 0.02), Pal.CHARCOAL)


static func _syrup_level(b: MeshBuilder) -> void:
	b.block(Vector3.ZERO, Vector3(0.05, 1.0, 0.05), Color("7a2a1c"))


## A bar's beer tap: dark wood bar with a brass foot rail and an open front
## showing the keg, a chrome T-tower with three tall tap handles.
static func _beer_tap(b: MeshBuilder) -> void:
	var wood := Color("5e3d2a")
	b.block(Vector3(0, 0, -0.03), Vector3(0.86, 0.09, 0.78), Pal.RUBBER, 0.01)
	b.block(Vector3(0, 0.08, -0.4), Vector3(0.94, H - TOP_T - 0.08, 0.08), wood, 0.02)
	for x in [-0.43, 0.43]:
		b.block(Vector3(x, 0.08, 0.0), Vector3(0.08, H - TOP_T - 0.08, 0.88), wood, 0.02)
	b.block(Vector3(0, 0.08, 0.0), Vector3(0.94, 0.06, 0.88), wood.darkened(0.2), 0.01)
	# The keg inside
	b.cyl(Vector3(0, 0.14, -0.05), 0.27, 0.5, Pal.STEEL, 12, 0.03)
	for y in [0.2, 0.56]:
		b.cyl(Vector3(0, 0.14 + y * 0.9, -0.05), 0.285, 0.04, Pal.STEEL_DARK, 12)
	b.cyl(Vector3(0, 0.64, -0.05), 0.06, 0.04, Pal.CHARCOAL, 8)
	# Brass foot rail
	b.push_at(Vector3(-0.45, 0.16, 0.5), 0.0, Vector3.ONE, 0.0, -PI / 2.0)
	b.cyl(Vector3.ZERO, 0.025, 0.9, Color("c9a24a"), 8)
	b.pop()
	worktop(b, Color("3e2a1e"))
	# Chrome T-tower
	b.cyl(Vector3(0, H, -0.2), 0.055, 0.36, Pal.STEEL, 10)
	b.push_at(Vector3(-0.27, H + 0.4, -0.2), 0.0, Vector3.ONE, 0.0, -PI / 2.0)
	b.cyl(Vector3.ZERO, 0.05, 0.54, Pal.STEEL, 10, 0.01)
	b.pop()
	b.cyl(Vector3(0, H + 0.33, -0.142), 0.06, 0.012, Color("c9a24a"), 12)
	var handles := [Color("c9a24a"), Color("b3263a"), Color("2a2a2c")]
	for k in 3:
		var x := -0.2 + k * 0.2
		b.cyl(Vector3(x, H + 0.3, -0.16), 0.016, 0.08, Pal.STEEL_DARK, 6)
		b.box(Vector3(x, H + 0.51, -0.18), Vector3(0.05, 0.2, 0.05), handles[k], 0.014)
		b.box(Vector3(x, H + 0.62, -0.18), Vector3(0.06, 0.03, 0.06), handles[k].lightened(0.25), 0.01)
	# Drip tray
	b.block(Vector3(0, H, 0.17), Vector3(0.6, 0.04, 0.3), Pal.STEEL_DARK, 0.012)
	for k in 4:
		b.box(Vector3(0, H + 0.044, 0.07 + k * 0.065), Vector3(0.56, 0.008, 0.02), Pal.CHARCOAL)


static func _keg_level(b: MeshBuilder) -> void:
	b.cyl(Vector3.ZERO, 0.09, 1.0, Pal.STEEL, 10)
