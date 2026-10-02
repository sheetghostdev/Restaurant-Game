class_name BuildManager
extends Node
## Build mode: lifting, carrying, rotating and placing fixtures; unpacking
## purchased equipment; buying expansions, upgrades and staff; and knocking
## doorways through walls. Construction only happens in calm phases.

const KNOCK_COST := 60.0
const BRICK_COST := 30.0

var world: GameWorld
var upgrades := {}          ## id -> times bought
var _ghosts := {}           ## player -> Node3D
var _wall_handles: Array[WallHandle] = []


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld
	Events.phase_changed.connect(_on_phase)


func save_data() -> Dictionary:
	var u := {}
	for k in upgrades:
		u[String(k)] = upgrades[k]
	return {"upgrades": u}


func load_data(d: Dictionary) -> void:
	upgrades.clear()
	var u: Dictionary = d.get("upgrades", {})
	for k in u:
		upgrades[StringName(k)] = int(u[k])


func has_upgrade(id: StringName) -> bool:
	return upgrades.get(id, 0) > 0


# -----------------------------------------------------------------------------
# Lifting & placing fixtures
# -----------------------------------------------------------------------------

func placement_cell(p: Node3D) -> Vector2i:
	var fwd: Vector3 = p.facing_dir()
	var c := GameConst.world_to_cell(p.global_position + fwd * 0.95)
	var pc := GameConst.world_to_cell(p.global_position)
	if c == pc:
		c = GameConst.world_to_cell(p.global_position + fwd * 1.4)
	return c


func _cell_clear_of_items(c: Vector2i) -> bool:
	for it in world.items_root.get_children():
		if it is Item and GameConst.world_to_cell((it as Item).global_position) == c:
			return false
	for a in get_tree().get_nodes_in_group(&"actors"):
		if GameConst.world_to_cell((a as Node3D).global_position) == c:
			return false
	return true


func can_place_at(c: Vector2i, def: FixtureDef, ignore: Fixture = null) -> bool:
	return world.grid.can_place(c, def, ignore) and _cell_clear_of_items(c)


func try_lift(p: PlayerCharacter, f: Fixture) -> bool:
	if not world.is_calm() or p.carried_fixture or p.held() or not f.can_lift():
		return false
	world.grid.vacate(f)
	f.set_lifted(true)
	f.get_parent().remove_child(f)
	p.add_child(f)
	f.position = Vector3(0, 0.55, 0.62)
	f.rotation = Vector3(0, f.rot * PI * 0.5 - p.rotation.y, 0)
	f.scale = Vector3.ONE * 0.75
	f.carrier_id = p.net_id
	p.carried_fixture = f
	Audio.play_at(&"build_lift", f.global_position)
	f.mark_dirty()
	world.customers.mark_tables_dirty()
	return true


func rotate_carried(p: PlayerCharacter) -> void:
	var f := p.carried_fixture
	if f == null:
		return
	f.rot = (f.rot + 1) % 4
	# The carried model faces its landing direction (clients do the same in
	# Fixture.set_location).
	var holder := f.get_parent() as Node3D
	if holder:
		f.rotation = Vector3(0, f.rot * PI * 0.5 - holder.rotation.y, 0)
	Audio.play_at(&"ui_click", f.global_position)
	f.mark_dirty()


func try_place_carried(p: PlayerCharacter) -> bool:
	var f := p.carried_fixture
	if f == null:
		return false
	var c := placement_cell(p)
	if not can_place_at(c, f.def, f):
		Audio.play_at(&"error", p.global_position)
		return false
	_put_down(p, f, c)
	return true


func _put_down(p: PlayerCharacter, f: Fixture, c: Vector2i) -> void:
	p.carried_fixture = null
	p.remove_child(f)
	world.fixtures_root.add_child(f)
	f.scale = Vector3.ONE
	f.carrier_id = 0
	f.place_at(c, f.rot)
	f.set_lifted(false)
	world.grid.occupy(f)
	f.bump()
	Audio.play_at(&"build_place", f.global_position)
	world.fx.dust(f.global_position)
	f.mark_dirty()
	world.customers.mark_tables_dirty()
	Events.build_changed.emit()


## Phase changes force anything being carried back onto the grid.
func drop_all_carried() -> void:
	for p in world.players():
		drop_carried(p)


## Force-places whatever `p` is carrying at the nearest free cell.
func drop_carried(p: PlayerCharacter) -> void:
	var f: Fixture = p.carried_fixture
	if f == null:
		return
	_put_down(p, f, nearest_free(f.cell, f.def, f))


func nearest_free(start: Vector2i, def: FixtureDef, f: Fixture) -> Vector2i:
	if can_place_at(start, def, f):
		return start
	for r in range(1, 12):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var c := start + Vector2i(dx, dz)
				if can_place_at(c, def, f):
					return c
	return start


func try_unpack(p: PlayerCharacter) -> bool:
	var pkg := p.held() as PackageItem
	if pkg == null or not world.is_calm():
		return false
	var fd := pkg.fixture_def()
	if fd == null:
		return false
	var c := placement_cell(p)
	if not can_place_at(c, fd):
		return false
	var rot := GameConst.rot_from_dir(-_snap_dir(p.facing_dir()))
	world.despawn(pkg)
	var f := world.spawn_fixture(fd.id, c, rot)
	if f:
		f.bump()
		_init_new_fixture(f)
	Audio.play_at(&"construct", GameConst.cell_center(c))
	world.fx.dust(GameConst.cell_center(c))
	world.fx.sparkle(GameConst.cell_center(c) + Vector3(0, 0.8, 0), Color("ffe08a"))
	Events.build_changed.emit()
	return true


func _init_new_fixture(f: Fixture) -> void:
	# New racks come with a starter set of dishware.
	var rack := f.get_component("DishRack") as DishRack
	if rack and rack.count == 0:
		rack.count = 4
		f.mark_dirty()


func _snap_dir(v: Vector3) -> Vector2i:
	if absf(v.x) > absf(v.z):
		return Vector2i(int(signf(v.x)), 0)
	return Vector2i(0, int(signf(v.z)))


# -----------------------------------------------------------------------------
# Purchases
# -----------------------------------------------------------------------------

func buy_fixture(def_id: StringName) -> bool:
	var fd := Content.fixture(def_id)
	if fd == null or not fd.purchasable:
		return false
	if not world.economy.spend(fd.price, fd.display_name):
		return false
	world.deliveries.order_package(def_id)
	Events.notify("%s ordered — it'll be on the loading dock" % fd.display_name, &"info")
	return true


func buy_upgrade(id: StringName) -> bool:
	var u: UpgradeDef = Content.upgrades.get(id)
	if u == null:
		return false
	if not u.repeatable and has_upgrade(id):
		return false
	if not world.economy.spend(u.price, u.display_name):
		return false
	upgrades[id] = upgrades.get(id, 0) + 1
	_apply_upgrade(u)
	Audio.play_ui(&"level_up")
	Events.notify("Upgrade: %s" % u.display_name, &"info")
	return true


func _apply_upgrade(u: UpgradeDef) -> void:
	match u.effect:
		&"extra_plates":
			for f in world.grid.all_fixtures():
				var r := f.get_component("DishRack") as DishRack
				if r and r.kind == "plate":
					r.count += int(u.amount)
					f.mark_dirty()
					return
		&"extra_mugs":
			for f in world.grid.all_fixtures():
				var r2 := f.get_component("DishRack") as DishRack
				if r2 and r2.kind == "mug":
					r2.count += int(u.amount)
					f.mark_dirty()
					return
		&"extinguisher":
			world.deliveries.pending.push_back({"at": 0.0, "vehicle": "van", "items": [{"package": "extinguisher_station"}], "label": "Safety kit"})


func buy_expansion(exp_id: StringName) -> bool:
	var e: ExpansionDef = Content.expansions.get(exp_id)
	if e == null or exp_id in world.grid.built_expansions:
		return false
	if not world.is_calm():
		Events.notify("Construction can only happen outside service hours", &"error")
		return false
	if not world.economy.spend(e.price, e.display_name):
		return false
	world.grid.built_expansions.push_back(exp_id)
	world.grid.add_room(exp_id, e.room_type, e.rect)
	for d in e.doors:
		var a := Vector2i(d.x, d.y)
		var b := Vector2i(d.z, d.w)
		_clear_doorway(a, e.rect)
		_clear_doorway(b, e.rect)
		world.grid.set_opening(a, b, "door")
	for sf in e.starter_fixtures:
		var c: Vector2i = sf.get("cell", Vector2i.ZERO)
		if world.grid.fixture_at(c) == null:
			var f := world.spawn_fixture(StringName(sf.get("def", "counter")), c, int(sf.get("rot", 0)))
			if f:
				_init_new_fixture(f)
	world.replicator.publish(&"layout", world.grid.save_layout())
	setup_plots()
	_construction_fx(e.rect)
	world.customers.mark_tables_dirty()
	Events.notify("%s built!" % e.display_name, &"big", Pal.UI_GOOD)
	return true


## Moves a fixture out of the way when a new doorway is built through its cell.
func _clear_doorway(c: Vector2i, new_rect: Rect2i) -> void:
	var f := world.grid.fixture_at(c)
	if f == null or not f.def.blocks_movement:
		return
	world.grid.vacate(f)
	var target := c
	var found := false
	for r in range(1, 10):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if found or maxi(absi(dx), absi(dz)) != r:
					continue
				var n := c + Vector2i(dx, dz)
				if new_rect.has_point(n) or world.grid.room_index(n) != world.grid.room_index(c):
					continue
				if can_place_at(n, f.def, f):
					target = n
					found = true
		if found:
			break
	f.place_at(target, f.rot)
	world.grid.occupy(f)
	f.mark_dirty()
	if found:
		Events.notify("Moved the %s to make room for the new doorway" % f.display_name(), &"info")


func _construction_fx(r: Rect2i) -> void:
	Audio.play_at(&"construct", Vector3(r.get_center().x, 0, r.get_center().y))
	world.camera.add_shake(0.5)
	for x in range(r.position.x, r.end.x, 2):
		for z in range(r.position.y, r.end.y, 2):
			world.fx.dust(Vector3(x + 0.5, 0.2, z + 0.5))


func available_expansions() -> Array[ExpansionDef]:
	var out: Array[ExpansionDef] = []
	if world.location == null:
		return out
	for id in world.location.expansions:
		var e: ExpansionDef = Content.expansions.get(id)
		if e == null or id in world.grid.built_expansions:
			continue
		if e.requires != &"" and not (e.requires in world.grid.built_expansions):
			continue
		out.push_back(e)
	return out


func setup_plots() -> void:
	if not Net.is_authority():
		return
	for p in world.all_of_kind(&"plot"):
		world.despawn(p)
	for e in available_expansions():
		var sign_at := Vector2(e.rect.get_center().x, e.rect.end.y - 0.5)
		world.spawn_entity(&"plot", e.id, {}, {"pos": [sign_at.x, 0, sign_at.y], "yaw": 0.0})


# -----------------------------------------------------------------------------
# Walls
# -----------------------------------------------------------------------------

func _on_phase(_phase: int) -> void:
	_refresh_wall_handles()


func _refresh_wall_handles() -> void:
	for h in _wall_handles:
		if is_instance_valid(h):
			h.queue_free()
	_wall_handles.clear()
	if world == null or world.day == null or not world.is_calm():
		return
	var g := world.grid
	var seen := {}
	for room in g.rooms:
		var rect: Rect2i = room["rect"]
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				var a := Vector2i(x, z)
				for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
					var b: Vector2i = a + d
					var key := RestaurantGrid.edge_key(a, b)
					if seen.has(key):
						continue
					seen[key] = true
					if not g.is_building(b) or g.room_index(a) == g.room_index(b):
						continue
					var op := g.opening_type(a, b)
					if op == "front":
						continue
					if op == "" and not g.wall_between(a, b):
						continue
					var h := WallHandle.new()
					h.manager = self
					h.a = a
					h.b = b
					world.effects_root.add_child(h)
					_wall_handles.push_back(h)


func toggle_opening(a: Vector2i, b: Vector2i) -> bool:
	if not world.is_calm():
		return false
	var g := world.grid
	var op := g.opening_type(a, b)
	if op == "":
		for c in [a, b]:
			var f := g.fixture_at(c)
			if f and f.def.blocks_movement:
				Events.notify("Move the %s out of the way first" % f.display_name(), &"error")
				return false
		if not world.economy.spend(KNOCK_COST, "Knock through wall"):
			return false
		g.set_opening(a, b, "door")
	else:
		if not world.economy.spend(BRICK_COST, "Wall up doorway"):
			return false
		g.set_opening(a, b, "")
	world.customers.mark_tables_dirty()
	world.replicator.publish(&"layout", g.save_layout())
	Audio.play_at(&"construct", (GameConst.cell_center(a) + GameConst.cell_center(b)) * 0.5)
	world.fx.dust((GameConst.cell_center(a) + GameConst.cell_center(b)) * 0.5 + Vector3(0, 0.6, 0))
	world.camera.add_shake(0.25)
	_refresh_wall_handles()
	return true


# -----------------------------------------------------------------------------
# Ghost previews (local players)
# -----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if world == null or world.grid == null:
		return
	var calm := world.day != null and world.is_calm()
	var live := {}
	for p in world.players():
		if not p.is_local():
			continue
		var fd: FixtureDef = null
		var rot := 0
		var ignore: Fixture = null
		if p.carried_fixture:
			fd = p.carried_fixture.def
			rot = p.carried_fixture.rot
			ignore = p.carried_fixture
		elif p.held() is PackageItem and calm:
			fd = (p.held() as PackageItem).fixture_def()
			rot = GameConst.rot_from_dir(-_snap_dir(p.facing_dir()))
		if fd == null:
			continue
		live[p] = true
		var g: Node3D = _ghosts.get(p)
		if g == null or g.get_meta(&"def") != fd.id:
			if g:
				g.queue_free()
			g = _make_ghost(fd)
			world.effects_root.add_child(g)
			_ghosts[p] = g
		var c := placement_cell(p)
		g.position = GameConst.cell_center(c)
		g.rotation.y = rot * PI * 0.5
		var ok := can_place_at(c, fd, ignore)
		var mat := Models.mat_ghost(ok)
		for mi in Item._mesh_instances(g):
			mi.material_override = mat
	for p in _ghosts.keys():
		if not live.has(p):
			if is_instance_valid(_ghosts[p]):
				_ghosts[p].queue_free()
			_ghosts.erase(p)


func _make_ghost(fd: FixtureDef) -> Node3D:
	var root := Node3D.new()
	root.set_meta(&"def", fd.id)
	var key := fd.model if fd.model != &"" else fd.id
	var m := Models.instance(key)
	root.add_child(m)
	var floor_mark := MeshInstance3D.new()
	var b := MeshBuilder.new()
	b.block(Vector3.ZERO, Vector3(0.96, 0.02, 0.96), Color(1, 1, 1))
	floor_mark.mesh = b.commit()
	root.add_child(floor_mark)
	return root
