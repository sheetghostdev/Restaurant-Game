class_name TrainLine
extends Node3D
## The Dining Car Express: the restaurant is a train.
##
## Mornings it waits at the depot and evenings at the terminus. During service
## it stops a few times. At every stop the doors open and market stalls set up
## on the platform: there is no delivery truck, so this is where ingredients
## come from, and every stop has different deals. Passengers board too. When
## the whistle blows the doors shut and the train pulls out: anything still on
## the platform is left behind (players get hauled back aboard).
##
## The train itself never moves: the platform slides in and out and the
## scenery scrolls past. The host runs the timetable; clients animate from
## the shared "train" state.

enum State { STOPPED, DEPARTING, MOVING, ARRIVING }

const STOP_TIME := 40.0            ## Seconds at a stop during service.
const SLIDE_TIME := 5.0            ## Arriving / departing.
const WHISTLE_AT := 10.0           ## Warning before the doors shut.
const CRUISE := 7.0                ## Scenery speed while moving (m/s).
const STOP_AT := [0.2, 0.47, 0.74] ## Service progress at each stop.
const PLATFORM_RUN := 40.0         ## How far the platform slides in/out.
const DEAL_OFF := 0.35             ## Each stop's specialty is this much cheaper.

var world: GameWorld
var state := State.STOPPED
var t := 0.0                       ## Seconds in the current state.
var station := ""                  ## Where we are (or were).
var next_station := ""
var stops_done := 0
var market_open := false
var _phase := -1
var _speed := 0.0
var _scroll := 0.0
var _platform: Node3D
var _platform_parts: Array = []    ## [node, home_x]
var _scenery_parts: Array = []     ## [node, home_x, kind] kind: 0 always, 2 only between stations
var _spinners: Array = []          ## [wheel node, radius]
var _rods: Array = []              ## [rod node, centre wheel position]
var _cars: Node3D
var _loco_x := 0.0
var _smoke_t := 0.0
var _ground := -0.95
var _x0 := -8.0
var _x1 := 26.0
var _sync_t := 0.0
var _whistled := false
var _status := ""


func _ready() -> void:
	var lot := world.grid.lot
	_x0 = lot.position.x
	_x1 = lot.end.x
	_ground = world.builder.ground_y
	_build_cars()
	world.grid.layout_changed.connect(_build_cars)
	_build_scenery()
	_build_platform()
	if Net.is_authority():
		world.grid.set_locked("train_door", false)


# -----------------------------------------------------------------------------
# Timetable (host)
# -----------------------------------------------------------------------------

func _stops() -> PackedStringArray:
	return world.location.stops if not world.location.stops.is_empty() else PackedStringArray(["Central Depot", "Millbrook", "Cedar Falls", "Port Quinn"])


func _station_name(i: int) -> String:
	var s := _stops()
	if i <= 0:
		return s[0]
	# Intermediate stops rotate through the line, a different set every day.
	var k := 1 + posmod(world.day.day * 3 + i - 1, s.size() - 1)
	return s[k]


func _physics_process(delta: float) -> void:
	if world == null or world.day == null:
		return
	t += delta
	if not Net.is_authority():
		return
	var phase := world.day.phase
	if phase != _phase:
		_on_phase(phase)
	match state:
		State.STOPPED:
			if phase in [GameConst.Phase.SERVICE, GameConst.Phase.CLOSING] and stops_done > 0:
				var left := STOP_TIME - t
				if left <= WHISTLE_AT and not _whistled:
					_whistled = true
					Audio.play_at(&"truck_horn", Vector3(14, 0, 6), 2.0, 1.6)
					Events.notify("All aboard! Doors close in %d seconds" % int(WHISTLE_AT), &"big", Pal.UI_WARN)
				if left <= 0.0:
					_depart()
		State.DEPARTING:
			if t >= SLIDE_TIME:
				_set_state(State.MOVING)
				Events.notify("Next stop: %s" % next_station, &"info")
		State.MOVING:
			# stops_done: stations visited since the depot (0 = just left it).
			var i := stops_done + 1
			if phase == GameConst.Phase.SERVICE and i <= STOP_AT.size():
				if world.day.elapsed / world.format.service_seconds >= float(STOP_AT[i - 1]):
					_arrive(_station_name(i))
		State.ARRIVING:
			if t >= SLIDE_TIME:
				_stopped()
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.25
		_publish()


func _on_phase(phase: int) -> void:
	var prev := _phase
	_phase = phase
	match phase:
		GameConst.Phase.MORNING:
			# A new day starts at the depot with the big market.
			stops_done = 0
			station = _station_name(0)
			next_station = _station_name(1)
			_set_state(State.STOPPED)
			world.grid.set_locked("train_door", false)
			_open_market(true)
		GameConst.Phase.SERVICE:
			if prev == GameConst.Phase.MORNING and state == State.STOPPED:
				stops_done = 0
				next_station = _station_name(1)
				_depart()
		GameConst.Phase.RESULTS, GameConst.Phase.EVENING:
			if state != State.STOPPED or market_open:
				# Pull into the terminus (snap: the results card is up).
				_close_market()
				station = "%s (terminus)" % _stops()[_stops().size() - 1]
				_set_state(State.STOPPED)
				world.grid.set_locked("train_door", false)


func _set_state(s: State) -> void:
	state = s
	t = 0.0
	_publish()


func _depart() -> void:
	_close_market()
	_leave_behind()
	world.grid.set_locked("train_door", true)
	Audio.play_at(&"truck_horn", Vector3(14, 0, 6), 0.0, 1.4)
	_whistled = false
	_set_state(State.DEPARTING)


func _arrive(name_text: String) -> void:
	station = name_text
	_set_state(State.ARRIVING)
	Events.notify("Arriving at %s" % station, &"info")


func _stopped() -> void:
	_set_state(State.STOPPED)
	_whistled = false
	world.grid.set_locked("train_door", false)
	Audio.play_at(&"door_bell", Vector3(18.5, 0, 6), 0.0, 0.8)
	stops_done += 1
	var deal := _open_market(false)
	next_station = _station_name(stops_done + 1) if stops_done < STOP_AT.size() else _stops()[_stops().size() - 1]
	Events.notify("%s! Market's open for %d seconds%s" % [station, int(STOP_TIME), (" — %s is cheap here" % deal) if deal != "" else ""], &"big", Pal.UI_GOOD)
	# Hungry passengers hop on here: they walk in from the platform through
	# the coach doors and queue for the dining car.
	if world.day.phase == GameConst.Phase.SERVICE:
		var archs := world.format.archetypes
		var spots: Array = world.layout_data().get("street", {}).get("board", [[-4, 7]])
		for i in randi_range(2, 3):
			var a := Content.archetype(archs[randi() % archs.size()])
			if a and a.min_day <= world.day.day:
				var c: Array = spots[i % spots.size()]
				world.customers.spawn_group(a, false, Vector2i(int(c[0]), int(c[1])))


# -----------------------------------------------------------------------------
# Market
# -----------------------------------------------------------------------------

## Sets up stalls on the platform. The depot sells everything at list price;
## other stops sell a few things, one of them at a discount. Returns the deal.
func _open_market(depot: bool) -> String:
	_close_market()
	var cells: Array = world.layout_data().get("market_cells", [])
	var supplies := Content.supplies_for(world.format)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.day.day, stops_done, station])
	var picks := supplies.duplicate()
	if not depot:
		# Fisher-Yates with the stop's seed, so a stop's stock is repeatable.
		for i in range(picks.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = picks[i]
			picks[i] = picks[j]
			picks[j] = tmp
		picks = picks.slice(0, mini(picks.size(), rng.randi_range(3, 4)))
	var deal := ""
	for i in mini(picks.size(), cells.size()):
		var s: SupplyDef = picks[i]
		var price := s.price
		var stock := 4 if depot else 2
		var tag := ""
		if not depot:
			if i == 0:
				price *= 1.0 - DEAL_OFF
				stock = 3
				tag = "deal"
				deal = s.display_name
			else:
				price *= rng.randf_range(0.95, 1.25)
		var c: Array = cells[i]
		var cell := Vector2i(int(c[0]), int(c[1]))
		if world.grid.fixture_at(cell):
			continue
		world.spawn_fixture(&"market_stall", cell, 2, {"MarketStall": {"s": String(s.id), "p": snappedf(price, 0.5), "n": stock, "tag": tag}})
	market_open = true
	return deal


func _close_market() -> void:
	for f in world.grid.fixtures_of(&"market_stall"):
		world.despawn(f)
	market_open = false


## Departing: whatever is still out on the platform stays there, and anyone
## outside is pulled back through the nearest door.
func _leave_behind() -> void:
	var lost := 0
	for it in world.loose_items():
		var c := GameConst.world_to_cell((it as Item).global_position)
		if not world.grid.is_inside(c):
			lost += 1
			world.despawn(it)
	if lost > 0:
		Events.notify("Left behind on the platform: %d item%s" % [lost, "" if lost == 1 else "s"], &"warning")
	var inside := world.grid.street_point("inside_door", Vector2i(18, 4))
	for a in world.players() + world.all_of_kind(&"staff"):
		var n := a as Node3D
		if n and not world.grid.is_inside(GameConst.world_to_cell(n.global_position)):
			n.global_position = GameConst.cell_center(inside) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
			if n is PlayerCharacter:
				Events.notify("%s nearly missed the train!" % (n as PlayerCharacter).display_name(), &"warning")
	# Passengers still on the platform wait for the next train.
	var missed := 0
	for g in world.customers.groups.duplicate():
		for m in g.members:
			if not world.grid.is_inside(GameConst.world_to_cell(m.global_position)):
				missed += g.members.size()
				world.customers.drop_group(g)
				break
	if missed > 0:
		Events.notify("%d passenger%s missed the train" % [missed, "" if missed == 1 else "s"], &"info")


# -----------------------------------------------------------------------------
# Shared state
# -----------------------------------------------------------------------------

func _publish() -> void:
	world.replicator.publish(&"train", {"s": state, "t": snappedf(t, 0.05), "st": station, "nx": next_station, "n": stops_done, "m": market_open})


func apply_shared(d: Dictionary) -> void:
	var s: int = int(d.get("s", state))
	if s != state or absf(float(d.get("t", t)) - t) > 0.5:
		t = float(d.get("t", t))
	state = s as State
	station = String(d.get("st", station))
	next_station = String(d.get("nx", next_station))
	stops_done = int(d.get("n", stops_done))
	market_open = bool(d.get("m", market_open))
	# Doors are shut whenever the train isn't standing at a platform.
	world.grid.set_locked("train_door", state != State.STOPPED)


## One line for the HUD under the clock.
func status_line() -> String:
	match state:
		State.STOPPED:
			if world.day and world.day.phase in [GameConst.Phase.SERVICE, GameConst.Phase.CLOSING] and stops_done > 0:
				return "At %s · leaves in %d s" % [station, maxi(0, int(ceil(STOP_TIME - t)))]
			return "At %s" % station
		State.ARRIVING:
			return "Arriving: %s" % station
		_:
			var i := stops_done + 1
			if world.day and world.day.phase == GameConst.Phase.SERVICE and i <= STOP_AT.size():
				var prog := world.day.elapsed / world.format.service_seconds
				var secs: float = (float(STOP_AT[i - 1]) - prog) * world.format.service_seconds
				return "Next stop: %s · %d s" % [next_station, maxi(0, int(secs))]
			return "Next stop: %s" % next_station


# -----------------------------------------------------------------------------
# Visuals (everyone)
# -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	var target := 0.0
	var px := 0.0
	var k := clampf(t / SLIDE_TIME, 0.0, 1.0)
	match state:
		State.MOVING:
			target = CRUISE
		State.DEPARTING:
			target = CRUISE * k
			px = -PLATFORM_RUN * k * k
		State.ARRIVING:
			target = CRUISE * (1.0 - k)
			px = PLATFORM_RUN * (1.0 - k) * (1.0 - k)
		State.STOPPED:
			target = 0.0
	_speed = move_toward(_speed, target, delta * 4.0)
	_scroll += _speed * delta
	var span := _x1 - _x0
	for e in _scenery_parts:
		var n: Node3D = e[0]
		n.position.x = _x0 + fposmod(float(e[1]) - _scroll - _x0, span)
		if int(e[2]) == 2:
			n.visible = state == State.MOVING
	# Wheels roll and the locomotive's coupling rods go round.
	for sp in _spinners:
		(sp[0] as Node3D).rotation.z -= _speed * delta / float(sp[1])
	for r in _rods:
		var wheel: Node3D = r[2]
		var a := wheel.rotation.z
		(r[0] as Node3D).position = (r[1] as Vector3) + Vector3(cos(a), sin(a), 0) * 0.36
	_smoke(delta)
	var platform_here := state != State.MOVING
	_platform.visible = platform_here
	if platform_here:
		for e in _platform_parts:
			var n2: Node3D = e[0]
			var x: float = float(e[1]) + px
			n2.position.x = x
			n2.visible = x > _x0 - 0.01 and x < _x1 + 0.01
		var lbl: Label3D = _platform.get_meta(&"label")
		var want := station.replace(" (terminus)", "").to_upper()
		if lbl.text != want:
			lbl.text = want


## Smoke from the locomotive's chimney: thick and fast on the move, a lazy
## wisp while standing.
func _smoke(delta: float) -> void:
	if world == null or world.fx == null:
		return
	_smoke_t -= delta
	if _smoke_t > 0.0:
		return
	var fast := _speed / CRUISE
	_smoke_t = lerpf(1.6, 0.18, fast)
	var at := Vector3(_loco_x + 7.95, 4.3, 3.0)
	if fast > 0.1:
		world.fx.smoke(at, 0.8 + fast * 0.8, true)
	else:
		world.fx.steam(at, 0.6, Color(1, 1, 1, 0.5), true)


## The cars (indoor rooms only, not the platform).
func _train_rect() -> Rect2i:
	var r := Rect2i()
	for room in world.grid.rooms:
		var rt := Content.room_type(room["type"])
		if rt and not rt.outdoor:
			r = room["rect"] if r.size == Vector2i.ZERO else r.merge(room["rect"])
	return r


## Everything that makes the building read as a train: rails, the
## undercarriage and bogies of every car, arched car ends, a roof edge, two
## closed passenger cars behind and the locomotive in front.
func _build_cars() -> void:
	if _cars:
		_cars.queue_free()
	_cars = Node3D.new()
	_cars.name = "Cars"
	add_child(_cars)
	var r := dress(_cars, world.grid, _ground, _x0, _x1)
	_spinners = r["spinners"]
	_rods = r["rods"]
	_loco_x = r["loco_x"]


## Builds the train's rolling stock under `parent` (also used by the title
## screen's preview). Returns the wheels and rods that turn while moving.
static func dress(parent: Node3D, grid: RestaurantGrid, ground: float, x0: float, x1: float) -> Dictionary:
	var spinners := []
	var rods := []
	var b := MeshBuilder.new()
	var rail_y := ground + 0.012
	var steel := Color("8c8f94")
	for z in [-0.2, 6.2, -2.3, -1.3]:
		b.block(Vector3((x0 + x1) * 0.5, rail_y, z), Vector3(x1 - x0 - 0.02, 0.05, 0.07), steel, 0.01)
	# The playable cars, west to east
	var spans := []
	var train := Rect2i()
	for room in grid.rooms:
		var rt := Content.room_type(room["type"])
		if rt == null or rt.outdoor:
			continue
		var rr: Rect2i = room["rect"]
		spans.push_back([float(rr.position.x), float(rr.end.x)])
		train = rr if train.size == Vector2i.ZERO else train.merge(rr)
	spans.sort_custom(func(a, c): return a[0] < c[0])
	var done := {}
	for sp in spans:
		var cx0: float = sp[0]
		var cx1: float = sp[1]
		if cx1 - cx0 < 3.0:
			continue   # the gangway between the coach and the next car
		_undercarriage(parent, b, spinners, ground, cx0, cx1)
		for bx in [cx0, cx1]:
			if not done.has(bx):
				done[bx] = true
				_arch(b, bx)
		b.block(Vector3((cx0 + cx1) * 0.5, 2.56, 0.12), Vector3(cx1 - cx0, 0.13, 0.5), ModelsWorld.LIVERY, 0.02)
	# Two passenger cars behind (you can't go in) and the engine in front.
	var west := float(train.position.x)
	for k in 2:
		var px1 := west - k * 7.95
		var px0 := px1 - 7.8
		var car := Models.instance(&"passenger_car")
		car.position = Vector3((px0 + px1) * 0.5, 0, 0)
		parent.add_child(car)
		_undercarriage(parent, b, spinners, ground, px0, px1)
	var loco_x := float(train.end.x) + 0.15
	var loco := Models.instance(&"locomotive")
	loco.position = Vector3(loco_x, 0, 0)
	parent.add_child(loco)
	var wy := rail_y + 0.05 + 0.85
	var drivers: Array[Node3D] = []
	for x in [3.4, 5.2, 7.0]:
		var w := Models.instance(&"loco_wheel")
		w.position = Vector3(loco_x + x, wy, 5.62)
		parent.add_child(w)
		spinners.push_back([w, 0.85])
		drivers.push_back(w)
	var rod := Models.instance(&"coupling_rod")
	rod.position = drivers[1].position + Vector3(0.36, 0, 0.14)
	parent.add_child(rod)
	rods.push_back([rod, drivers[1].position + Vector3(0, 0, 0.14), drivers[1]])
	for x in [0.9, 8.4]:
		var pw := Models.instance(&"train_wheel")
		pw.scale = Vector3.ONE * 1.6
		pw.position = Vector3(loco_x + x, rail_y + 0.05 + 0.38, 5.55)
		parent.add_child(pw)
		spinners.push_back([pw, 0.38])
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Models.mat_main())
	parent.add_child(mi)
	return {"spinners": spinners, "rods": rods, "loco_x": loco_x}


## Chassis, the body's skirt below the floor, and two bogies with wheels.
static func _undercarriage(parent: Node3D, b: MeshBuilder, spinners: Array, ground: float, x0: float, x1: float) -> void:
	var cx := (x0 + x1) * 0.5
	var l := x1 - x0
	b.block(Vector3(cx, -0.36, 3.0), Vector3(l - 0.3, 0.34, 5.6), Color("26282c"), 0.02)
	b.block(Vector3(cx, -0.38, 6.03), Vector3(l - 0.1, 0.38, 0.08), ModelsWorld.LIVERY, 0.01)
	b.block(Vector3(cx, -0.38, -0.03), Vector3(l - 0.1, 0.38, 0.08), ModelsWorld.LIVERY, 0.01)
	b.block(Vector3(cx, -0.12, 6.08), Vector3(l - 0.2, 0.04, 0.02), ModelsWorld.CREAM)
	var rail_top := ground + 0.062
	for bx in [x0 + 1.4, x1 - 1.4]:
		var bogie := Models.instance(&"bogie")
		bogie.position = Vector3(bx, rail_top + 0.36, 6.32)
		parent.add_child(bogie)
		b.block(Vector3(bx, rail_top + 0.48, 3.0), Vector3(0.5, -0.36 - rail_top - 0.48, 6.0), Color("1f2124"))
		for dx in [-0.6, 0.6]:
			var w := Models.instance(&"train_wheel")
			w.scale = Vector3.ONE * 1.5
			w.position = Vector3(bx + dx, rail_top + 0.36, 6.2)
			parent.add_child(w)
			spinners.push_back([w, 0.36])


## The rounded top of a car end, standing on the end wall at x.
static func _arch(b: MeshBuilder, x: float) -> void:
	var n := 12
	for i in n:
		var z0 := 6.0 * i / n
		var zc := z0 + 3.0 / n
		var h := 0.55 * sqrt(maxf(1.0 - pow((zc - 3.0) / 3.0, 2.0), 0.0))
		if h < 0.04:
			continue
		b.block(Vector3(x, 2.55, zc), Vector3(0.24, h, 6.0 / n + 0.005), ModelsWorld.LIVERY)
		b.block(Vector3(x, 2.55 + h, zc), Vector3(0.27, 0.04, 6.0 / n + 0.005), Pal.WALL_CAP)


func _scenery(key: StringName, x: float, z: float, yaw := 0.0, s := 1.0, kind := 0) -> void:
	var n := Models.instance(key)
	var y := _ground + (0.012 if key == &"rail_sleeper" or key == &"long_sleeper" else 0.02)
	n.position = Vector3(x, y, z)
	n.rotation.y = deg_to_rad(yaw)
	n.scale = Vector3.ONE * s
	add_child(n)
	_scenery_parts.push_back([n, x, kind])


func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x := _x0
	# Sleepers under both tracks scroll by (the train's own show past its
	# ends and, between stations, along its side).
	while x < _x1:
		_scenery(&"rail_sleeper", x + 0.3, -1.8)
		_scenery(&"long_sleeper", x + 0.3, 3.0)
		x += 0.6
	# Telegraph poles, trees and hills behind; a fence and bushes in front.
	x = _x0
	while x < _x1:
		_scenery(&"telegraph_pole", x + 1.0, -0.75)
		x += 6.0
	x = _x0
	while x < _x1:
		var key: StringName = [&"tree", &"tree", &"bush", &"hill"][rng.randi_range(0, 3)]
		_scenery(key, x + rng.randf() * 1.5, rng.randf_range(-3.0, -2.8) if key != &"hill" else -3.0, rng.randf() * 360.0, rng.randf_range(0.7, 1.15))
		x += rng.randf_range(1.6, 3.2)
	x = _x0
	while x < _x1:
		_scenery(&"fence_post", x, 9.4)
		x += 1.5
	# Between stations the platform is gone: fields rush past instead.
	x = _x0
	while x < _x1:
		var key2: StringName = [&"grass_tuft", &"grass_tuft", &"hay_bale", &"bush"][rng.randi_range(0, 3)]
		_scenery(key2, x, rng.randf_range(6.9, 8.8), rng.randf() * 360.0, rng.randf_range(0.6, 1.0), 2)
		x += rng.randf_range(0.8, 2.2)
	x = _x0 + 3.0
	while x < _x1:
		_scenery(&"telegraph_pole", x, 8.9, 0.0, 1.0, 2)
		x += 9.0
	x = _x0 + 0.7
	while x < _x1:
		_scenery([&"bush", &"tree"][rng.randi_range(0, 1)], x, rng.randf_range(9.5, 9.8), rng.randf() * 360.0, rng.randf_range(0.5, 0.8))
		x += rng.randf_range(3.0, 6.0)


func _platform_part(key: StringName, x: float, z: float, yaw := 0.0, s := 1.0) -> Node3D:
	var n := Models.instance(key)
	n.position = Vector3(x, 0, z)
	n.rotation.y = deg_to_rad(yaw)
	n.scale = Vector3.ONE * s
	_platform.add_child(n)
	_platform_parts.push_back([n, x])
	return n


## A raised platform level with the train's doors (the track is lower), as
## long as the model, with lamps, benches and the station's name.
func _build_platform() -> void:
	_platform = Node3D.new()
	_platform.name = "Platform"
	add_child(_platform)
	# One-metre slabs so the platform can be clipped at the edge of the model.
	var x := int(_x0)
	while x < int(_x1):
		_platform_part(&"platform_slab", x + 0.5, 7.5)
		x += 1
	for lx in [-5.5, 2.5, 17.5, 23.5, 30.5, -12.5, -19.5]:
		_platform_part(&"lamp_post", lx, 8.75, 180.0)
	for bx in [-2.0, 26.5, -15.5]:
		_platform_part(&"bench", bx, 8.55, 180.0)
	var sign := _platform_part(&"station_sign", 0.6, 8.6)
	var lbl := Label3D.new()
	lbl.font = load("res://art/fonts/AlfaSlabOne-Regular.ttf")
	lbl.font_size = 64
	lbl.pixel_size = 0.0045
	lbl.modulate = Pal.UI_INK
	lbl.outline_size = 0
	lbl.position = Vector3(0, 1.62, 0.07)
	lbl.shaded = false
	lbl.name = "StationName"
	sign.add_child(lbl)
	_platform.set_meta(&"label", lbl)
