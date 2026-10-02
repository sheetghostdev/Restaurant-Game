class_name CustomerManager
extends Node
## Spawns customer groups through the day, manages the physical queue outside
## the front door, groups tables into clusters, and seats groups.
##
## Arrivals follow a demand curve with predictable rushes (lunch, dinner) and
## archetype preferences (work crews at lunch, dates in the evening...), so
## players can plan for them during prep.

const QUEUE_PATIENCE := 70.0
const ORDER_PATIENCE := 38.0
const FOOD_PATIENCE := 75.0
const MAX_QUEUE_PEOPLE := 14
const QUEUE_SPACING := 0.78

var world: GameWorld
var groups: Array[CustomerGroup] = []
var schedule: Array = []           ## [[hour, archetype_id], ...] sorted
var forecast := {}                 ## hour -> expected groups (for the prep UI)
var demand_mods := {}              ## hour -> multiplier (from events)
var _sched_i := 0
var _tables_dirty := true
var _clusters: Array = []          ## [{tables: Array[Fixture], seats: Array}]
var _reserved := {}                ## Fixture -> CustomerGroup
var _next_group := 1
var _seat_t := 0.0
var _queue_t := 0.0


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld


# -----------------------------------------------------------------------------
# Schedule
# -----------------------------------------------------------------------------

func plan_day(day: int, reputation: float) -> void:
	schedule.clear()
	forecast.clear()
	_sched_i = 0
	var fmt := world.format
	var loc_demand := world.location.demand if world.location else 1.0
	var growth := minf(1.0 + (day - 1) * 0.16, 2.6)
	var rep_mult := 0.75 + reputation * 0.13
	var n := int(round(fmt.base_groups * growth * rep_mult * loc_demand))
	n = maxi(n, 4)
	var hours: Array[int] = []
	var weights: Array[float] = []
	for h in range(fmt.open_hour, fmt.close_hour):
		hours.push_back(h)
		var w := float(fmt.hourly_demand.get(h, fmt.hourly_demand.get(str(h), 1.0)))
		w *= float(demand_mods.get(h, 1.0))
		weights.push_back(w)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day * 7919 + int(reputation * 100))
	var archs := _eligible_archetypes(day, reputation)
	var per_day := {}
	for i in n:
		var h: int = _weighted_pick(hours, weights, rng)
		var t: float = h + rng.randf() * 0.95
		var a := _pick_archetype(archs, h, rng)
		if a == null:
			continue
		if a.max_per_day > 0:
			per_day[a.id] = per_day.get(a.id, 0) + 1
			if per_day[a.id] > a.max_per_day:
				continue
		schedule.push_back([t, String(a.id)])
		forecast[h] = forecast.get(h, 0) + 1
	schedule.sort_custom(func(x, y): return x[0] < y[0])


func _eligible_archetypes(day: int, rep: float) -> Array[CustomerArchetype]:
	var out: Array[CustomerArchetype] = []
	for id in world.format.archetypes:
		var a := Content.archetype(id)
		if a and a.min_day <= day and a.min_reputation <= rep:
			out.push_back(a)
	return out


func _pick_archetype(archs: Array[CustomerArchetype], hour: int, rng: RandomNumberGenerator) -> CustomerArchetype:
	var total := 0.0
	for a in archs:
		total += a.spawn_weight * a.weight_at_hour(hour)
	if total <= 0.0:
		return archs[0] if not archs.is_empty() else null
	var r := rng.randf() * total
	for a in archs:
		r -= a.spawn_weight * a.weight_at_hour(hour)
		if r <= 0.0:
			return a
	return archs[archs.size() - 1]


func _weighted_pick(items: Array, weights: Array, rng: RandomNumberGenerator) -> Variant:
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in items.size():
		r -= weights[i]
		if r <= 0.0:
			return items[i]
	return items[items.size() - 1]


func rush_hours() -> Array:
	var out := []
	var fmt := world.format
	for h in range(fmt.open_hour, fmt.close_hour):
		var w := float(fmt.hourly_demand.get(h, fmt.hourly_demand.get(str(h), 1.0))) * float(demand_mods.get(h, 1.0))
		if w >= 1.6:
			out.push_back(h)
	return out


func is_rush_hour(hour: float) -> bool:
	return int(floor(hour)) in rush_hours()


# -----------------------------------------------------------------------------
# Tick
# -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null or not Net.is_authority() or world.day == null:
		return
	if world.day.phase == GameConst.Phase.SERVICE:
		while _sched_i < schedule.size() and schedule[_sched_i][0] <= world.day.hour:
			spawn_group(Content.archetype(StringName(schedule[_sched_i][1])))
			_sched_i += 1
	for g in groups.duplicate():
		g.tick(delta)
	_seat_t -= delta
	if _seat_t <= 0.0:
		_seat_t = 0.4
		_try_seating()
	_queue_t -= delta
	if _queue_t <= 0.0:
		_queue_t = 0.5
		_update_queue()


func spawn_group(a: CustomerArchetype, force := false) -> CustomerGroup:
	if a == null:
		return null
	var waiting := 0
	for g in groups:
		if g.state in [CustomerGroup.State.ARRIVING, CustomerGroup.State.QUEUED]:
			waiting += g.members.size()
	var g := CustomerGroup.new()
	g.id = _next_group
	_next_group += 1
	g.archetype = a
	g.manager = self
	var size := randi_range(a.group_min, a.group_max)
	if waiting + size > MAX_QUEUE_PEOPLE and not force:
		# They see the line and walk on by.
		world.day.record_balk(size)
		Events.notify("A %s saw the line and left" % a.display_name.to_lower(), &"warning")
		return null
	var from_left := randf() < 0.5
	var spawn := world.grid.street_point("spawn_a" if from_left else "spawn_b", Vector2i(-3, 12))
	for i in size:
		var app := _appearance_for(a, i)
		var child: bool = i > 0 and randf() < a.child_chance
		if child:
			app["scale"] = 0.74
		var st := {"a": String(a.id), "app": _app_save(app), "m": 1.0}
		var c: Customer = world.spawn_entity(&"customer", &"customer", st, {"pos": [spawn.x + 0.5 + randf_range(-0.3, 0.3), 0, spawn.y + 0.5 + i * 0.5], "yaw": 0.0})
		c.archetype = a
		c.group = g
		c.is_child = child
		c.speed = a.walk_speed * randf_range(0.92, 1.08)
		g.members.push_back(c)
	groups.push_back(g)
	g.start(GameConst.cell_center(spawn))
	_update_queue(true)
	return g


func _app_save(app: Dictionary) -> Dictionary:
	var out := {}
	for k in app:
		var v = app[k]
		out[k] = v.to_html() if v is Color else (String(v) if v is StringName else v)
	return out


func _appearance_for(a: CustomerArchetype, index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if a.fixed_look_seed > 0:
		rng.seed = a.fixed_look_seed + index
	else:
		rng.randomize()
	var app := CharacterRig.random_appearance(rng)
	if not a.outfit_colors.is_empty():
		app["shirt"] = a.outfit_colors[rng.randi_range(0, a.outfit_colors.size() - 1)]
	match a.accessory:
		&"hard_hat":
			app["hat"] = &"hard_hat"
			app["hat_color"] = Color("f2c230") if rng.randf() < 0.7 else Color("f28c28")
			app["accessory"] = &"vest" if rng.randf() < 0.6 else &""
		&"tie":
			app["accessory"] = &"tie"
			app["shirt"] = [Color("3f4f5f"), Color("2e3440"), Color("5f5f6e")][rng.randi_range(0, 2)]
			app["hair_style"] = [&"short", &"bun", &"pony"][rng.randi_range(0, 2)]
		&"camera":
			app["accessory"] = &"camera"
			if rng.randf() < 0.6:
				app["hat"] = &"sun_hat"
				app["hat_color"] = Color("e9d9a6")
		&"beret":
			app["hat"] = &"beret"
			app["hat_color"] = Color("2e2622")
			app["accessory"] = &"notebook"
			app["glasses"] = true
		&"backpack":
			app["accessory"] = &"backpack"
			app["hat"] = &"cap" if rng.randf() < 0.5 else &"none"
			app["hat_color"] = Color("7a8f5a")
		&"bowtie":
			app["accessory"] = &"bowtie"
		&"bow":
			app["hat"] = &"bow"
			app["hat_color"] = Pal.DINER_RED
	return app


func on_group_gone(g: CustomerGroup) -> void:
	groups.erase(g)


# -----------------------------------------------------------------------------
# Queue
# -----------------------------------------------------------------------------

func front_door_pos() -> Vector3:
	var fd := world.grid.front_door
	return Vector3(fd.z + 0.5, 0, fd.w + 0.5)


func exit_cell() -> Vector2i:
	return world.grid.street_point("spawn_a" if randf() < 0.5 else "spawn_b", Vector2i(-3, 12))


func queue_point(k: int) -> Vector3:
	var start := world.grid.street_point("queue", Vector2i(4, 10))
	var dir_a = world.grid.street.get("queue_dir", [-1, 0])
	var dir := Vector3(float(dir_a[0]), 0, float(dir_a[1]))
	var side := Vector3(float(dir_a[1]), 0, -float(dir_a[0])) * 0.0
	return GameConst.cell_center(start) + dir * (k * QUEUE_SPACING) + side


func _update_queue(force := false) -> void:
	var k := 0
	for g in groups:
		if g.state != CustomerGroup.State.ARRIVING and g.state != CustomerGroup.State.QUEUED:
			continue
		for m in g.members:
			var p := queue_point(k)
			k += 1
			if not force and m.has_meta(&"qp") and (m.get_meta(&"qp") as Vector3).distance_to(p) < 0.05:
				continue
			m.set_meta(&"qp", p)
			var gg := g
			var face_door := front_door_pos()
			var cb := func():
				gg.on_reached_queue()
				var to := face_door - m.global_position
				m.face(atan2(to.x, to.z))
			m.walk_path_to(p, cb)


# -----------------------------------------------------------------------------
# Tables
# -----------------------------------------------------------------------------

func mark_tables_dirty() -> void:
	_tables_dirty = true


func _rebuild_clusters() -> void:
	_tables_dirty = false
	_clusters.clear()
	var tables: Array = []
	for f in world.grid.all_fixtures():
		if f.get_component("SeatingTable") and not f.lifted:
			tables.push_back(f)
	tables.sort_custom(func(a, b): return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x))
	var by_cell := {}
	for i in tables.size():
		var st := tables[i].get_component("SeatingTable") as SeatingTable
		if st.number != i + 1:
			st.number = i + 1
			tables[i].mark_dirty()
		by_cell[tables[i].cell] = tables[i]
	var seen := {}
	for t in tables:
		if seen.has(t):
			continue
		var cluster := {"tables": [], "seats": []}
		var stack := [t]
		seen[t] = true
		while not stack.is_empty():
			var cur: Fixture = stack.pop_back()
			cluster["tables"].push_back(cur)
			for d in SeatingTable.SIDES:
				var n = by_cell.get(cur.cell + d)
				if n and not seen.has(n) and not world.grid.wall_between(cur.cell, cur.cell + d):
					seen[n] = true
					stack.push_back(n)
		for tf in cluster["tables"]:
			var st2 := tf.get_component("SeatingTable") as SeatingTable
			for side in st2.seated_sides():
				cluster["seats"].push_back({"table": tf, "side": side})
		_clusters.push_back(cluster)


func clusters() -> Array:
	if _tables_dirty:
		_rebuild_clusters()
	return _clusters


## Decor in customer areas makes waiting more pleasant (patience bonus).
func ambience_bonus() -> float:
	var total := 0.0
	for f in world.grid.all_fixtures():
		if f.def and f.def.ambience > 0.0 and world.grid.is_customer_area(f.cell):
			total += f.def.ambience
	return minf(total, 0.25)


func total_seats() -> int:
	var n := 0
	for c in clusters():
		n += c["seats"].size()
	return n


func _cluster_free(c: Dictionary) -> bool:
	for t in c["tables"]:
		if _reserved.has(t):
			return false
		var st := (t as Fixture).get_component("SeatingTable") as SeatingTable
		if not st.is_clean():
			return false
	return not c["seats"].is_empty()


func _try_seating() -> void:
	if world.day.phase != GameConst.Phase.SERVICE and world.day.phase != GameConst.Phase.CLOSING:
		return
	for g in groups:
		if g.state != CustomerGroup.State.QUEUED:
			continue
		var best: Dictionary = {}
		for c in clusters():
			if not _cluster_free(c):
				continue
			if c["seats"].size() < g.members.size():
				continue
			if best.is_empty() or c["seats"].size() < best["seats"].size():
				best = c
		if best.is_empty():
			continue
		for t in best["tables"]:
			_reserved[t] = g
		g.seat_at(best["tables"], best["seats"])
		_update_queue()
		return


func group_at_table(t: Fixture) -> CustomerGroup:
	return _reserved.get(t)


func release_tables(g: CustomerGroup) -> void:
	for t in g.tables:
		if _reserved.get(t) == g:
			_reserved.erase(t)


# -----------------------------------------------------------------------------
# Orders
# -----------------------------------------------------------------------------

func choose_orders(a: CustomerArchetype, child: bool) -> Array:
	var menu := Content.menu_for(world.format, world.day.day)
	var food: Array[RecipeDef] = []
	var drinks: Array[RecipeDef] = []
	for r in menu:
		if r.container == "mug":
			drinks.push_back(r)
		else:
			food.push_back(r)
	var out := []
	var n := 1 if child else randi_range(a.dishes_min, a.dishes_max)
	var picked := {}
	for i in n:
		var total := 0.0
		for r in food:
			if picked.has(r.id):
				continue
			total += r.menu_weight * float(a.recipe_weights.get(String(r.id), a.recipe_weights.get(r.id, 1.0)))
		if total <= 0.0:
			break
		var roll := randf() * total
		for r in food:
			if picked.has(r.id):
				continue
			roll -= r.menu_weight * float(a.recipe_weights.get(String(r.id), a.recipe_weights.get(r.id, 1.0)))
			if roll <= 0.0:
				picked[r.id] = true
				out.push_back({"recipe": r.id})
				break
	if not child and not drinks.is_empty() and randf() < a.drink_chance and out.size() < 2:
		out.push_back({"recipe": drinks[randi() % drinks.size()].id})
	if out.is_empty() and not food.is_empty():
		out.push_back({"recipe": food[0].id})
	return out


# -----------------------------------------------------------------------------
# Day transitions
# -----------------------------------------------------------------------------

## Closing time: anyone still waiting outside goes home.
func on_closing() -> void:
	for g in groups.duplicate():
		if g.state in [CustomerGroup.State.ARRIVING, CustomerGroup.State.QUEUED]:
			for m in g.members:
				m.bubble = "wait"
				m.mark_dirty()
			g._leave()


func active_groups() -> int:
	return groups.size()


func seated_or_waiting_people() -> int:
	var n := 0
	for g in groups:
		n += g.members.size()
	return n


## Removes everyone immediately (debug / reset).
func clear_all() -> void:
	for g in groups.duplicate():
		for m in g.members.duplicate():
			world.despawn(m)
		g.members.clear()
	groups.clear()
	_reserved.clear()
	world.orders.clear()
