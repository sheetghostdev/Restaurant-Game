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
var _sched_i := 0
var _tables_dirty := true
var _clusters: Array = []          ## [{tables: Array[Fixture], seats: Array}]
var _reserved := {}                ## Fixture -> CustomerGroup
var _next_group := 1
var _seat_t := 0.0
var _renumber_queued := false
var _queue_t := 0.0


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld


# -----------------------------------------------------------------------------
# Schedule
# -----------------------------------------------------------------------------

## Groups expected on `day` at this reputation (the forecast's number).
func expected_groups(day: int, reputation: float) -> int:
	var fmt := world.format
	var loc_demand := world.location.demand if world.location else 1.0
	var growth := minf(1.0 + (day - 1) * 0.16, 2.6)
	var rep_mult := 0.75 + reputation * 0.13
	return maxi(int(round(fmt.base_groups * growth * rep_mult * loc_demand * Difficulty.factor("groups"))), 3)


func plan_day(day: int, reputation: float) -> void:
	schedule.clear()
	forecast.clear()
	_sched_i = 0
	var fmt := world.format
	var n := expected_groups(day, reputation)
	var hours: Array[int] = []
	var weights: Array[float] = []
	var total_w := 0.0
	for h in range(fmt.open_hour, fmt.close_hour):
		hours.push_back(h)
		var w := float(fmt.hourly_demand.get(h, fmt.hourly_demand.get(str(h), 1.0)))
		weights.push_back(w)
		total_w += w
	# Share the day's groups out by the demand curve (largest remainder), so
	# the rush hours are reliably the busy ones. Only arrival times within an
	# hour and who turns up are random.
	var per_hour: Array[int] = []
	var rest := []
	var given := 0
	for i in hours.size():
		var exact := n * weights[i] / maxf(total_w, 0.001)
		per_hour.push_back(int(floor(exact)))
		given += per_hour[i]
		rest.push_back([exact - floor(exact), i])
	rest.sort_custom(func(a, b): return a[0] > b[0])
	for k in n - given:
		per_hour[rest[k % rest.size()][1]] += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day * 7919 + int(reputation * 100))
	var archs := _eligible_archetypes(day, reputation)
	var per_day := {}
	for i in hours.size():
		var h := hours[i]
		var count := per_hour[i]
		for j in count:
			var t: float = h + (j + rng.randf_range(0.05, 0.85)) / count
			var a: CustomerArchetype = null
			for attempt in 6:
				a = _pick_archetype(archs, h, rng)
				if a == null or a.max_per_day <= 0 or per_day.get(a.id, 0) < a.max_per_day:
					break
				a = null
			if a == null:
				continue
			per_day[a.id] = per_day.get(a.id, 0) + 1
			schedule.push_back([t, String(a.id)])
			forecast[h] = forecast.get(h, 0) + 1
	schedule.sort_custom(func(x, y): return x[0] < y[0])
	# Nobody waits for the first customer: the first group is queuing at the
	# door before opening (see early_arrival) and the next one follows soon.
	if schedule.size() >= 2:
		schedule[1][0] = minf(schedule[1][0], fmt.open_hour + 0.12)


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


func rush_hours() -> Array:
	var out := []
	var fmt := world.format
	for h in range(fmt.open_hour, fmt.close_hour):
		var w := float(fmt.hourly_demand.get(h, fmt.hourly_demand.get(str(h), 1.0)))
		if w >= 1.6:
			out.push_back(h)
	return out


func is_rush_hour(hour: float) -> bool:
	return int(floor(hour)) in rush_hours()


# -----------------------------------------------------------------------------
# Tick
# -----------------------------------------------------------------------------

## Shortly before opening the first group of the day turns up and waits at
## the door (they're not impatient yet: the restaurant isn't open).
func early_arrival() -> void:
	if _sched_i >= schedule.size():
		return
	var g := spawn_group(Content.archetype(StringName(schedule[_sched_i][1])), true)
	_sched_i += 1
	if g:
		Events.notify("The first guests are waiting at the door!", &"info")


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


## `at`: where they appear (a train platform at a stop); by default they
## arrive along the street (or from the train's other cars).
func spawn_group(a: CustomerArchetype, force := false, at := Vector2i(-99999, 0)) -> CustomerGroup:
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
	var group_size := randi_range(a.group_min, a.group_max)
	if waiting + group_size > MAX_QUEUE_PEOPLE and not force:
		# They see the line and walk on by.
		world.day.record_balk(group_size)
		Events.notify("A %s saw the line and left" % a.display_name.to_lower(), &"warning")
		return null
	var from_left := randf() < 0.5
	var spawn := world.grid.street_point("spawn_a" if from_left else "spawn_b", Vector2i(-3, 12))
	if at.x > -99999:
		spawn = at
	for i in group_size:
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
		&"scarf":
			# Commuters: dark coats, the odd beanie, a bag on the back.
			app["shirt"] = [Color("3f4f5f"), Color("6a4a3a"), Color("4a5a4a")][rng.randi_range(0, 2)]
			app["accessory"] = &"backpack" if rng.randf() < 0.5 else &""
			if rng.randf() < 0.4:
				app["hat"] = &"beanie"
				app["hat_color"] = Color("b5492e")
		&"glasses":
			app["glasses"] = true
			app["accessory"] = &"backpack" if rng.randf() < 0.6 else &"notebook"
			app["hat"] = &"beanie" if rng.randf() < 0.3 else &"none"
			app["hat_color"] = Color("3d7fd1")
		&"jersey":
			# Same team, mostly: caps in the team colour.
			app["hat"] = &"cap" if rng.randf() < 0.6 else &"none"
			app["hat_color"] = app["shirt"]
		&"bandana":
			app["hat"] = &"bandana" if rng.randf() < 0.5 else &"none"
			app["hat_color"] = Color("2e2622")
			app["shirt"] = [Color("2e3440"), Color("3a2a3a"), Color("5a2a2a")][rng.randi_range(0, 2)]
	if world.location and world.location.theme == "space" and rng.randf() < 0.6:
		# Travellers from all over: green, blue, violet... some with antennae.
		app["skin"] = [Color("8fd17f"), Color("7fb3e6"), Color("b28fd6"), Color("6fd3c0"), Color("e79ac7")][rng.randi_range(0, 4)]
		if app.get("hat", &"none") == &"none" or rng.randf() < 0.5:
			app["hat"] = &"antennae"
			app["hat_color"] = app["skin"]
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
	var seats := bench_seats()
	for g in groups:
		if g.state != CustomerGroup.State.ARRIVING and g.state != CustomerGroup.State.QUEUED:
			continue
		for m in g.members:
			# The first in line take the waiting benches; the rest queue as usual.
			if k < seats.size():
				var seat: Dictionary = seats[k]
				k += 1
				var sp: Vector3 = seat["pos"]
				if not force and m.has_meta(&"qp") and (m.get_meta(&"qp") as Vector3).distance_to(sp) < 0.05:
					continue
				m.set_meta(&"qp", sp)
				var gb := g
				var yaw: float = seat["yaw"]
				var mb := m
				m.walk_path_to(sp, func():
					gb.on_reached_queue()
					mb.set_meta(&"bench", true)
					mb.face(yaw)
					mb.seated = true
					mb.anim = CharacterRig.Anim.SIT
					mb.mark_dirty())
				continue
			if m.has_meta(&"bench"):
				m.remove_meta(&"bench")
				m.anim = CharacterRig.Anim.IDLE
			var p := queue_point(k - seats.size())
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
	# Renumber soon (not lazily at the next seating) so every table shows its
	# colour from the start and right after furniture moves.
	if Net.is_authority() and not _renumber_queued:
		_renumber_queued = true
		_renumber.call_deferred()


func _renumber() -> void:
	_renumber_queued = false
	if _tables_dirty and world and world.grid:
		_rebuild_clusters()


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
		by_cell[tables[i].cell] = tables[i]
	var fd := world.grid.front_door
	var entry := Vector2i(fd.x, fd.y)
	var seen := {}
	for t in tables:
		if seen.has(t):
			continue
		var cluster := {"tables": [], "seats": []}
		var stack := [t]
		seen[t] = true
		# Tables pushed together are one table: same number, same colour.
		var number := _clusters.size() + 1
		while not stack.is_empty():
			var cur: Fixture = stack.pop_back()
			cluster["tables"].push_back(cur)
			var st := cur.get_component("SeatingTable") as SeatingTable
			if st.number != number:
				st.number = number
				cur.mark_dirty()
			for d in SeatingTable.SIDES:
				var n = by_cell.get(cur.cell + d)
				if n and not seen.has(n) and not world.grid.wall_between(cur.cell, cur.cell + d):
					seen[n] = true
					stack.push_back(n)
		for tf in cluster["tables"]:
			var st2 := tf.get_component("SeatingTable") as SeatingTable
			for side in st2.seated_sides():
				# Skip chairs nobody can walk to (boxed in, or a walled-up room).
				if not world.grid.guest_nav.reachable(entry, tf.cell + SeatingTable.SIDES[side]):
					continue
				cluster["seats"].push_back({"table": tf, "side": side})
		_clusters.push_back(cluster)


func clusters() -> Array:
	if _tables_dirty:
		_rebuild_clusters()
	return _clusters


## Most each kind of decor can add, however much of it you buy.
const DECOR_CAP := {"patience": 0.3, "eat_speed": 0.45, "tips": 0.4, "tidy": 0.75}
const DECOR_WORDS := {"patience": "guests wait %d%% longer", "eat_speed": "guests eat %d%% faster", "tips": "tips +%d%%", "tidy": "%d%% less mess"}


## The summed effect of one kind of decor in the dining areas, capped.
func decor_bonus(kind: String) -> float:
	var total := 0.0
	for f in world.grid.all_fixtures():
		if f.def == null or f.lifted or not world.grid.is_customer_area(f.cell):
			continue
		if f.def.decor == kind:
			total += f.def.decor_amount
		elif kind == "patience" and f.def.decor == "" and f.def.ambience > 0.0:
			total += f.def.ambience
	return minf(total, float(DECOR_CAP.get(kind, 0.5)))


## "guests wait 10% longer · tips +8%" for the catalog.
func decor_summary() -> String:
	var parts := []
	for k in DECOR_CAP:
		var v := decor_bonus(k)
		if v > 0.001:
			parts.push_back(String(DECOR_WORDS[k]) % roundi(v * 100.0))
	return " · ".join(parts)


func ambience_bonus() -> float:
	return decor_bonus("patience")


## Seats on waiting benches, in order: {pos, yaw}. People in line sit here
## first, and lose patience much more slowly.
func bench_seats() -> Array:
	var out := []
	var benches := world.grid.fixtures_of(&"waiting_bench").filter(func(f): return not f.lifted)
	benches.sort_custom(func(a, b): return a.cell.x < b.cell.x or (a.cell.x == b.cell.x and a.cell.y < b.cell.y))
	for f in benches:
		var yaw := atan2(f.front_vec().x, f.front_vec().z)
		for x in [-0.24, 0.24]:
			out.push_back({"pos": f.global_transform * Vector3(x, 0, 0.12), "yaw": yaw})
	return out


const BENCH_PATIENCE := 0.4


## How fast a queuing group loses patience: slower for those on benches.
func queue_patience_factor(g: CustomerGroup) -> float:
	if g.members.is_empty():
		return 1.0
	var sitting := 0
	for m in g.members:
		if m.has_meta(&"bench"):
			sitting += 1
	var frac := float(sitting) / g.members.size()
	return lerpf(1.0, BENCH_PATIENCE, frac)


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

## Chance a guest asks for each optional extra (lettuce, tomato...).
const EXTRA_CHANCE := 0.45
## Satisfaction lost when the dish a guest wanted is off the menu, and when
## an extra they wanted is.
const MISSING_DISH_PENALTY := 0.15
const MISSING_EXTRA_PENALTY := 0.07


## What one guest orders: {"orders": [{recipe, extras}], "penalty": float,
## "note": String}. Guests decide what they *want* from the full menu first;
## anything crossed off the menu board disappoints them (the penalty lowers
## their satisfaction) and they pick something else.
func choose_orders(a: CustomerArchetype, child: bool) -> Dictionary:
	var menu := Content.menu_for(world.format, world.day.day)
	var food: Array[RecipeDef] = []
	var drinks: Array[RecipeDef] = []
	for r in menu:
		if r.container == "mug":
			drinks.push_back(r)
		else:
			food.push_back(r)
	var res := {"orders": [], "penalty": 0.0, "note": ""}
	var fmt := world.format
	var n := 1 if child else randi_range(a.dishes_min, a.dishes_max)
	if not child and fmt and randf() >= fmt.food_chance:
		n = 0   # coffee shops and bars: plenty of people only want a drink
	var picked := {}
	for i in n:
		_order_one(food, a, picked, res, MISSING_DISH_PENALTY)
	var drink_p := a.drink_chance + (fmt.drink_bonus if fmt else 0.0)
	if not child and not drinks.is_empty() and randf() < drink_p and res["orders"].size() < 2:
		_order_one(drinks, a, picked, res, MISSING_DISH_PENALTY * 0.5)
	if res["orders"].is_empty() and res["note"] == "":
		var fallback := _pick_recipe(food, a, {}, true)
		if fallback == null:
			fallback = _pick_recipe(drinks, a, {}, true)
		if fallback:
			res["orders"].push_back(_with_extras(fallback, res))
	return res


## Picks what the guest wants from `list`. If it's crossed off the menu they
## are disappointed (penalty) and settle for something that is available.
func _order_one(list: Array[RecipeDef], a: CustomerArchetype, picked: Dictionary, res: Dictionary, penalty: float) -> void:
	var wish := _pick_recipe(list, a, picked, false)
	if wish == null:
		return
	picked[wish.id] = true
	var r := wish
	if world.orders.recipe_blocked(wish):
		res["penalty"] += penalty
		res["note"] = "No %s?" % wish.ticket_name().to_lower()
		r = _pick_recipe(list, a, picked, true)
		if r == null:
			return
		picked[r.id] = true
	res["orders"].push_back(_with_extras(r, res))


func _pick_recipe(list: Array[RecipeDef], a: CustomerArchetype, exclude: Dictionary, available_only: bool) -> RecipeDef:
	var total := 0.0
	for r in list:
		if exclude.has(r.id) or (available_only and world.orders.recipe_blocked(r)):
			continue
		total += r.menu_weight * float(a.recipe_weights.get(String(r.id), a.recipe_weights.get(r.id, 1.0)))
	if total <= 0.0:
		return null
	var roll := randf() * total
	for r in list:
		if exclude.has(r.id) or (available_only and world.orders.recipe_blocked(r)):
			continue
		roll -= r.menu_weight * float(a.recipe_weights.get(String(r.id), a.recipe_weights.get(r.id, 1.0)))
		if roll <= 0.0:
			return r
	return null


func _with_extras(r: RecipeDef, res: Dictionary) -> Dictionary:
	var extras: Array[StringName] = []
	for opt in r.optional:
		if randf() >= EXTRA_CHANCE:
			continue
		var base := Content.base_ingredient(opt)
		if world.orders.is_struck(base):
			res["penalty"] += MISSING_EXTRA_PENALTY
			res["note"] = "No %s?" % Content.display_name(base).to_lower()
		else:
			extras.push_back(opt)
	return {"recipe": r.id, "extras": extras}


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


## After last orders: anyone still seated finishes up and leaves (paying for
## what they ate), so the day can end.
func send_everyone_home() -> void:
	for g in groups.duplicate():
		if not g.is_leaving():
			g.go_home()


func active_groups() -> int:
	return groups.size()


func seated_or_waiting_people() -> int:
	var n := 0
	for g in groups:
		n += g.members.size()
	return n


## Removes everyone immediately (debug / reset).
## Removes one group without counting it as a walkout (they missed the train).
func drop_group(g: CustomerGroup) -> void:
	world.orders.cancel_group(g)
	release_tables(g)
	for m in g.members.duplicate():
		world.despawn(m)
	g.members.clear()
	groups.erase(g)
	_update_queue(true)


func clear_all() -> void:
	for g in groups.duplicate():
		for m in g.members.duplicate():
			world.despawn(m)
		g.members.clear()
	groups.clear()
	_reserved.clear()
	world.orders.clear()
