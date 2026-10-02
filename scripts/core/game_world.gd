class_name GameWorld
extends Node3D
## Root of a running restaurant session.
##
## Owns the entity registry (every networked/saved object has a net_id), spawns
## and despawns entities, drives the authority simulation tick and assembles
## save data. Systems (day cycle, customers, economy...) are child nodes under
## "Systems" and talk to each other through this world.

static var current: GameWorld

@onready var lighting: LightingRig = $Lighting
@onready var builder: RestaurantBuilder = $Builder
@onready var fixtures_root: Node3D = $Fixtures
@onready var items_root: Node3D = $Items
@onready var actors_root: Node3D = $Actors
@onready var effects_root: Node3D = $Effects
@onready var limbo: Node3D = $Limbo
@onready var camera: DioramaCamera = $Camera
@onready var grid: RestaurantGrid = $Systems/Grid
@onready var day: DayManager = $Systems/Day
@onready var economy: EconomyManager = $Systems/Economy
@onready var orders: OrderManager = $Systems/Orders
@onready var customers: CustomerManager = $Systems/Customers
@onready var deliveries: DeliveryManager = $Systems/Deliveries
@onready var build: BuildManager = $Systems/Build
@onready var disasters: EventManager = $Systems/Disasters
@onready var staff: StaffManager = $Systems/Staff
@onready var inventory: InventoryManager = $Systems/Inventory
@onready var interaction: InteractionSystem = $Systems/Interaction
@onready var replicator: Replicator = $Systems/Replicator
@onready var fx: FeedbackFX = $Systems/FX
@onready var hud: HUD = $UI/HUD

var entities := {}               ## net_id -> Node
var location: LocationDef
var format: RestaurantFormatDef
var restaurant_name := "The Corner Diner"
var unlocks: Array[StringName] = []
var _next_id := 1
var _layout := {}
var _started := false
var show_ai_states := false
var _nav_debug: MeshInstance3D
var _state_labels := {}

const KIND_ORDER := ["fixture", "plot", "player", "staff", "customer", "item", "mess", "truck"]


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null
		Events.world_closed.emit()


func _ready() -> void:
	lighting.builder = builder
	grid.layout_changed.connect(_on_layout_changed)
	Inputs.device_join_requested.connect(_on_join_requested)
	camera.tilt_shift = Settings.get_value("tilt_shift")


# -----------------------------------------------------------------------------
# Session setup
# -----------------------------------------------------------------------------

## Starts a brand new restaurant from a location's starting layout.
func start_new(location_id: StringName, format_id: StringName, name_text := "") -> void:
	location = Content.locations.get(location_id)
	format = Content.formats.get(format_id)
	if name_text != "":
		restaurant_name = name_text
	RecipeManager.menu = format.menu.duplicate()
	var layout := _read_json(location.layout_path)
	_layout = layout
	grid.load_layout(layout)
	builder.setup(grid, layout)
	builder.rebuild()
	if Net.is_authority():
		for f in layout.get("fixtures", []):
			var c: Array = f["cell"]
			spawn_fixture(StringName(f["def"]), Vector2i(c[0], c[1]), int(f.get("rot", 0)), f.get("state", {}))
		for it in layout.get("items", []):
			_spawn_layout_item(it)
		economy.setup_new(layout.get("money", 250.0), layout.get("reputation", 1.0))
		build.setup_plots()
		day.setup_new()
	_after_start()


## Restores a restaurant from save data.
func load_save(data: Dictionary) -> void:
	var meta: Dictionary = data.get("meta", {})
	location = Content.locations.get(StringName(meta.get("location", "main_street")))
	format = Content.formats.get(StringName(meta.get("format", "diner")))
	restaurant_name = meta.get("name", restaurant_name)
	RecipeManager.menu = format.menu.duplicate()
	_layout = _read_json(location.layout_path)
	grid.load_layout(data.get("layout", _layout))
	builder.setup(grid, _layout)
	builder.rebuild()
	unlocks.clear()
	for u in data.get("unlocks", []):
		unlocks.push_back(StringName(u))
	_next_id = 1
	var records: Array = data.get("entities", [])
	records.sort_custom(func(a, b): return KIND_ORDER.find(a.get("k", "")) < KIND_ORDER.find(b.get("k", "")))
	for r in records:
		if r.get("k") in ["player", "customer", "truck"]:
			continue
		spawn_entity(StringName(r["k"]), StringName(r.get("def", "")), r.get("st", {}), r.get("loc", {}), int(r.get("id", 0)))
	economy.load_data(data.get("economy", {}))
	deliveries.load_data(data.get("deliveries", {}))
	staff.load_data(data.get("staff", {}))
	build.load_data(data.get("build", {}))
	day.load_data(data.get("day", {}))
	build.setup_plots()
	_after_start()


func _after_start() -> void:
	_started = true
	var bounds := grid.building_bounds()
	camera.set_building_rect(Rect2(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y).grow(0.5))
	camera.snap()
	inventory.refresh()
	Events.world_ready.emit(self)


## Client: build the static restaurant from the host's data; entities arrive
## through replication.
func start_client(meta: Dictionary, layout: Dictionary) -> void:
	location = Content.locations.get(StringName(meta.get("location", "main_street")))
	format = Content.formats.get(StringName(meta.get("format", "diner")))
	restaurant_name = meta.get("name", restaurant_name)
	RecipeManager.menu = format.menu.duplicate()
	_layout = _read_json(location.layout_path)
	grid.load_layout(layout)
	builder.setup(grid, _layout)
	builder.rebuild()
	_after_start()


func client_init_meta() -> Dictionary:
	return {"location": String(location.id), "format": String(format.id), "name": restaurant_name}


# -----------------------------------------------------------------------------
# Players
# -----------------------------------------------------------------------------

func _free_index() -> int:
	var used := {}
	for p in players():
		used[p.player_index] = true
	for i in GameConst.MAX_PLAYERS:
		if not used.has(i):
			return i
	return -1


func _player_spawn(index: int) -> Vector3:
	var c := grid.street_point("player_spawn", Vector2i(12, 4))
	return GameConst.cell_center(c) + Vector3((index % 3 - 1) * 0.8, 0, (index / 3) * 0.8)


func add_local_player(device: int, pname := "") -> PlayerCharacter:
	if not Net.is_authority():
		return null
	var index := _free_index()
	if index < 0:
		return null
	if pname == "":
		pname = Settings.get_value("player_name") if index == 0 else Pal.PLAYER_COLOR_NAMES[index]
	var pos := _player_spawn(index)
	var p := spawn_entity(&"player", &"player", {"i": index, "peer": Net.my_id(), "n": pname, "dev": device}, {"pos": [pos.x, 0, pos.z], "yaw": PI}) as PlayerCharacter
	Inputs.claim(device, index)
	Events.player_joined.emit(p)
	if fx:
		fx.sparkle(pos + Vector3(0, 1.2, 0), p.actor_color())
	return p


func add_remote_player(peer_id: int, pname: String) -> PlayerCharacter:
	var index := _free_index()
	if index < 0:
		return null
	var pos := _player_spawn(index)
	var p := spawn_entity(&"player", &"player", {"i": index, "peer": peer_id, "n": pname, "dev": 0}, {"pos": [pos.x, 0, pos.z], "yaw": PI}) as PlayerCharacter
	Events.player_joined.emit(p)
	return p


func _on_join_requested(device: int) -> void:
	if not _started or not Net.is_authority() or hud == null or hud.is_modal_open():
		return
	if players().size() >= GameConst.MAX_PLAYERS:
		return
	var p := add_local_player(device)
	if p:
		Audio.play_ui(&"ui_confirm")
		Events.notify("%s joined!" % p.player_name, &"info")


func _process(_delta: float) -> void:
	if not _started:
		return
	camera.targets.clear()
	for p in players():
		camera.targets.push_back(p)
	if Input.is_action_just_pressed("overview_toggle"):
		camera.overview = not camera.overview
	if Input.is_action_just_pressed("zoom_in"):
		camera.zoom_bias = clampf(camera.zoom_bias - 0.08, -0.35, 0.35)
	if Input.is_action_just_pressed("zoom_out"):
		camera.zoom_bias = clampf(camera.zoom_bias + 0.08, -0.35, 0.35)
	if Input.is_action_just_pressed("quick_save") and Net.is_authority():
		if Saves.save_game(self):
			Events.notify("Game saved", &"info")
	_update_state_labels()


## True if a UI panel should swallow this local player's game input.
func input_blocked(p: PlayerCharacter) -> bool:
	if hud == null:
		return false
	if hud.catalog.blocks(p) or hud.pause_menu.visible or hud.results.visible:
		return true
	return false


# -----------------------------------------------------------------------------
# Debug
# -----------------------------------------------------------------------------

func debug_command(cmd: String, args: Array) -> void:
	match cmd:
		"spawn_customer":
			var a := Content.archetype(StringName(args[0]) if not args.is_empty() else &"regular_folks")
			if a == null:
				a = Content.archetypes.values()[0]
			customers.spawn_group(a, true)
			Events.notify("Spawned %s" % a.display_name, &"info")
		"spawn_delivery":
			var items := []
			for s in Content.supplies.values():
				items.push_back({"supply": String(s.id)})
			deliveries.schedule_extra(items, 0.5, "Debug delivery")
		"give_money":
			economy.earn(float(args[0]) if not args.is_empty() else 500.0, "Debug money")
		"advance_time":
			if day.phase == GameConst.Phase.SERVICE:
				var span := float(format.close_hour - format.open_hour)
				day.elapsed += format.service_seconds * float(args[0] if not args.is_empty() else 1.0) / span
		"start_service":
			if day.phase == GameConst.Phase.MORNING:
				day.open_restaurant()
			elif day.phase == GameConst.Phase.EVENING:
				day.start_next_day()
		"end_service":
			if day.phase == GameConst.Phase.SERVICE:
				day.elapsed = format.service_seconds
			elif day.phase == GameConst.Phase.CLOSING:
				customers.clear_all()
				day.finish_day()
			elif day.phase == GameConst.Phase.RESULTS:
				day.continue_from_results()
		"disaster":
			var id := StringName(args[0]) if not args.is_empty() else &"grease_fire"
			if not disasters.trigger(id):
				Events.notify("No valid target for %s" % id, &"warning")
		"reputation":
			economy.change_reputation(float(args[0]) if not args.is_empty() else 1.0)
		"spoil":
			for it in items_in_world():
				if it is CrateItem and (it as CrateItem).is_perishable():
					(it as CrateItem).spoil()
					break
		"clear_customers":
			customers.clear_all()


func toggle_nav_debug() -> void:
	if _nav_debug:
		_nav_debug.queue_free()
		_nav_debug = null
		return
	var b := MeshBuilder.new()
	b.ao_strength = 0.0
	for z in range(grid.lot.position.y, grid.lot.end.y):
		for x in range(grid.lot.position.x, grid.lot.end.x):
			var c := Vector2i(x, z)
			var col := Color(0.2, 0.9, 0.4) if grid.walkable(c) else Color(0.95, 0.25, 0.2)
			b.box(Vector3(x + 0.5, 0.03, z + 0.5), Vector3(0.18, 0.02, 0.18), col)
			if grid.wall_between(c, c + Vector2i(1, 0)):
				b.box(Vector3(x + 1.0, 0.05, z + 0.5), Vector3(0.06, 0.04, 0.8), Color(0.2, 0.3, 0.95))
			if grid.wall_between(c, c + Vector2i(0, 1)):
				b.box(Vector3(x + 0.5, 0.05, z + 1.0), Vector3(0.8, 0.04, 0.06), Color(0.2, 0.3, 0.95))
	_nav_debug = MeshInstance3D.new()
	_nav_debug.mesh = b.commit(Models.mat_unshaded(Color.WHITE))
	_nav_debug.material_override = null
	effects_root.add_child(_nav_debug)


func _update_state_labels() -> void:
	if not show_ai_states:
		for k in _state_labels:
			if is_instance_valid(_state_labels[k]):
				_state_labels[k].queue_free()
		_state_labels.clear()
		return
	for c in customers.groups:
		for m in c.members:
			var l: Label3D = _state_labels.get(m)
			if l == null or not is_instance_valid(l):
				l = Label3D.new()
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.no_depth_test = true
				l.pixel_size = 0.004
				l.font_size = 28
				l.position = Vector3(0, 2.2, 0)
				m.add_child(l)
				_state_labels[m] = l
			l.text = "%s\n%d%%" % [CustomerGroup.State.keys()[c.state], roundi(c.patience * 100)]


func _spawn_layout_item(it: Dictionary) -> void:
	var loc := {}
	if it.has("cell"):
		var c: Array = it["cell"]
		var f := grid.fixture_at(Vector2i(c[0], c[1]))
		if f and f.primary_slot():
			loc = {"slot": [f.net_id, int(it.get("slot", 0))]}
	if loc.is_empty() and it.has("floor"):
		var p: Array = it["floor"]
		loc = {"floor": [p[0], 0.0, p[1], 0.0]}
	if it.has("supply"):
		spawn_crate(StringName(it["supply"]), int(it.get("units", -1)), loc)
	elif it.has("def"):
		var st: Dictionary = it.get("state", {})
		spawn_item(StringName(it["def"]), st, loc)


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameWorld: cannot read layout %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func layout_data() -> Dictionary:
	return _layout


func make_save() -> Dictionary:
	var ents := []
	for id in entities:
		var e: Node = entities[id]
		if not is_instance_valid(e):
			continue
		var k: StringName = e.get_kind()
		if k in [&"player", &"customer", &"truck"]:
			continue
		if e is Item and (e as Item).holder() != null and (e as Item).holder().get_kind() in [&"player", &"customer"]:
			# Items in hands are dropped where the holder stands.
			var it := e as Item
			ents.push_back({"k": "item", "id": id, "def": String(it.def_id), "st": it.get_state(), "loc": {"floor": [it.global_position.x, 0.0, it.global_position.z, 0.0]}})
			continue
		ents.push_back({"k": String(k), "id": id, "def": String(e.def_id), "st": e.get_state(), "loc": e.get_location()})
	return {
		"version": GameConst.SAVE_VERSION,
		"meta": {
			"name": restaurant_name,
			"location": String(location.id) if location else "main_street",
			"format": String(format.id) if format else "diner",
			"day": day.day,
			"money": economy.money,
			"reputation": economy.reputation,
			"saved_at": Time.get_datetime_string_from_system(),
		},
		"layout": grid.save_layout(),
		"entities": ents,
		"economy": economy.save_data(),
		"deliveries": deliveries.save_data(),
		"staff": staff.save_data(),
		"build": build.save_data(),
		"day": day.save_data(),
		"unlocks": unlocks.map(func(u): return String(u)),
	}


func _on_layout_changed() -> void:
	if not _started:
		return
	builder.rebuild()
	var bounds := grid.building_bounds()
	camera.set_building_rect(Rect2(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y).grow(0.5))
	Events.build_changed.emit()


# -----------------------------------------------------------------------------
# Entity registry
# -----------------------------------------------------------------------------

func get_entity(id: int) -> Node:
	var e = entities.get(id)
	if e != null and not is_instance_valid(e):
		entities.erase(id)
		return null
	return e


func _register(e: Node, id: int) -> void:
	if id == 0:
		id = _next_id
	_next_id = maxi(_next_id, id + 1)
	e.set("net_id", id)
	e.set("world", self)
	entities[id] = e


## Generic spawn used by gameplay, save loading and network replication.
func spawn_entity(kind: StringName, def_id: StringName, state: Dictionary, loc: Dictionary, id := 0) -> Node:
	var e: Node = null
	match kind:
		&"item":
			e = _create_item(def_id)
			if e == null:
				return null
			_register(e, id)
			(e as Item).setup(Content.item(def_id))
			e.set_state(state)
			place_item(e, loc)
		&"fixture":
			var fd := Content.fixture(def_id)
			if fd == null or fd.scene == null:
				push_warning("Unknown fixture %s" % def_id)
				return null
			var f: Fixture = fd.scene.instantiate()
			f.setup(fd)
			_register(f, id)
			f.name = "%s_%d" % [def_id, f.net_id]
			f.set_location(loc)
			fixtures_root.add_child(f)
			f.set_state(state)
			grid.occupy(f)
			for c in f.components:
				c.on_placed()
			e = f
		&"player":
			var p: PlayerCharacter = preload("res://scenes/player/player.tscn").instantiate()
			_register(p, id)
			p.set_state(state)
			actors_root.add_child(p)
			p.set_location(loc)
			e = p
		&"customer":
			var c2 := Customer.new()
			_register(c2, id)
			c2.def_id = def_id
			actors_root.add_child(c2)
			c2.set_state(state)
			c2.set_location(loc)
			e = c2
		&"staff":
			var w := Worker.new()
			_register(w, id)
			w.def_id = def_id
			actors_root.add_child(w)
			w.set_state(state)
			w.set_location(loc)
			e = w
		&"mess":
			var m := Mess.new()
			_register(m, id)
			m.def_id = def_id
			effects_root.add_child(m)
			m.set_state(state)
			m.set_location(loc)
			e = m
		&"truck":
			var t := DeliveryTruck.new()
			_register(t, id)
			t.def_id = def_id
			effects_root.add_child(t)
			t.set_state(state)
			t.set_location(loc)
			e = t
		&"plot":
			var pl := ExpansionPlot.new()
			_register(pl, id)
			pl.def_id = def_id
			effects_root.add_child(pl)
			pl.set_state(state)
			pl.set_location(loc)
			e = pl
		_:
			push_warning("spawn_entity: unknown kind %s" % kind)
			return null
	if Net.is_authority():
		replicator.on_spawned(e)
	return e


func _create_item(def_id: StringName) -> Item:
	var d := Content.item(def_id)
	if d == null:
		push_warning("Unknown item %s" % def_id)
		return null
	match d.item_class:
		"food": return FoodItem.new()
		"dish": return DishItem.new()
		"crate": return CrateItem.new()
		"tool": return ToolItem.new()
		"package": return PackageItem.new()
		"trash": return TrashItem.new()
	return Item.new()


func spawn_item(def_id: StringName, state := {}, loc := {"none": true}) -> Item:
	return spawn_entity(&"item", def_id, state, loc) as Item


func spawn_crate(supply_id: StringName, units: int, loc: Dictionary) -> CrateItem:
	var s := Content.supply(supply_id)
	if s == null:
		push_warning("Unknown supply %s" % supply_id)
		return null
	var st := {"su": String(supply_id), "n": s.quantity if units < 0 else units}
	return spawn_entity(&"item", &"crate", st, loc) as CrateItem


func spawn_package(fixture_id: StringName, loc: Dictionary) -> PackageItem:
	return spawn_entity(&"item", &"package", {"f": String(fixture_id)}, loc) as PackageItem


func spawn_fixture(def_id: StringName, cell: Vector2i, rot: int, state := {}) -> Fixture:
	return spawn_entity(&"fixture", def_id, state, {"cell": [cell.x, cell.y], "rot": rot}) as Fixture


func despawn(e: Node) -> void:
	if e == null or not is_instance_valid(e):
		return
	var id: int = e.get("net_id")
	if Net.is_authority():
		replicator.on_despawned(e)
	if e is Item:
		var it := e as Item
		var held_by := it.holder()
		it.detach()
		if held_by and held_by.has_method("on_item_removed"):
			held_by.on_item_removed(it)
	elif e is Fixture:
		var f := e as Fixture
		for s in f.slots:
			if s.item:
				despawn(s.item)
		grid.vacate(f)
	entities.erase(id)
	if e.get_parent():
		e.get_parent().remove_child(e)
	e.queue_free()


## Resolves a location dictionary for an item (slot ref, floor or limbo).
func place_item(it: Item, loc: Dictionary) -> void:
	if loc.has("slot"):
		var ref: Array = loc["slot"]
		var owner_e := get_entity(int(ref[0]))
		if owner_e and owner_e.has_method("slot"):
			var s: ItemSlot = owner_e.slot(int(ref[1]))
			if s:
				if s.item and s.item != it:
					# Should not happen on the authority; on clients, move the
					# stale occupant aside until its own update arrives.
					var old := s.item
					old.detach()
					limbo.add_child(old)
				if s.item != it:
					s.put(it)
				return
	if loc.has("floor"):
		var p: Array = loc["floor"]
		it.place_on_floor(Vector3(p[0], p[1], p[2]), p[3] if p.size() > 3 else 0.0)
		return
	it.detach()
	limbo.add_child(it)


# -----------------------------------------------------------------------------
# Queries
# -----------------------------------------------------------------------------

func players() -> Array:
	var out := []
	for c in actors_root.get_children():
		if c is PlayerCharacter:
			out.push_back(c)
	return out


func all_of_kind(kind: StringName) -> Array:
	var out := []
	for e in entities.values():
		if is_instance_valid(e) and e.get_kind() == kind:
			out.push_back(e)
	return out


func items_in_world() -> Array:
	var out := []
	for e in entities.values():
		if is_instance_valid(e) and e is Item:
			out.push_back(e)
	return out


func loose_items() -> Array:
	var out := []
	for c in items_root.get_children():
		if c is Item:
			out.push_back(c)
	return out


# -----------------------------------------------------------------------------
# Simulation
# -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _started or not Net.is_authority():
		return
	if get_tree().paused:
		return
	for e in entities.values():
		if is_instance_valid(e) and e.is_inside_tree():
			e.server_tick(delta)


func stats_add(key: StringName, amount: float, sub: StringName = &"") -> void:
	day.stats_add(key, amount, sub)


func on_item_spoiled(it: Item) -> void:
	Audio.play_at(&"spoil", it.global_position)
	var n := it.display_name()
	Events.notify("%s went bad!" % n, &"warning")


func is_calm() -> bool:
	return GameConst.is_calm(day.phase)
