extends Node
## Headless gameplay test: boots a real restaurant and plays through a whole
## day using the same interaction code players use — delivery, prep, cooking,
## plating, customers, washing up, build mode, disasters, closing, results,
## next day and a save/load round trip.
## Run: godot --headless --path . res://tests/test_runner.tscn

var failures := 0
var checks := 0
var main: Node
var w: GameWorld
var p: PlayerCharacter
var _log: Array[String] = []


func _ready() -> void:
	Saves.active_slot = "test_run"
	Saves.delete()
	Engine.time_scale = 4.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.start_offline(false)
	await wait(0.6)
	w = GameWorld.current
	p = w.players()[0]
	check(w != null and p != null, "world and player exist")
	w.day.auto_open = false   # the morning tests take their time; t_service checks the auto-open
	await t_layout()
	await t_difficulty()
	await t_input_targeting()
	await t_delivery()
	await t_prep_and_cook()
	await t_plating_and_coffee()
	await t_build_mode()
	await t_service()
	await t_dishes()
	await t_disasters()
	await t_staff()
	await t_automation()
	await t_regressions()
	await t_round5()
	await t_menu_board()
	await t_spoilage()
	await t_consequences()
	await t_close_day()
	await t_save_load()
	print("")
	print("==== %d checks, %d failures ====" % [checks, failures])
	for l in _log:
		print(l)
	Saves.delete()
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures > 0 else 0)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)
		_log.push_back("FAIL: " + msg)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func fixture(def_id: StringName, i := 0) -> Fixture:
	var arr := w.grid.fixtures_of(def_id)
	arr.sort_custom(func(a, b): return a.cell.x < b.cell.x or (a.cell.x == b.cell.x and a.cell.y < b.cell.y))
	return arr[i] if i < arr.size() else null


## Stands the player in front of a target and faces it.
func approach(t: Node3D) -> void:
	var front := Vector3(0, 0, 1)
	if t is Fixture:
		front = (t as Fixture).front_vec()
	p.global_position = t.global_position + front * 0.85
	p.global_position.y = 0
	var to := t.global_position - p.global_position
	p.rotation.y = atan2(to.x, to.z)
	p.facing = Vector3(sin(p.rotation.y), 0, cos(p.rotation.y))


func grab(t: Node3D) -> bool:
	approach(t)
	return w.interaction._perform(t, p, GameConst.Verb.GRAB, 0.0)


func use(t: Node3D, hold := 0.0) -> bool:
	approach(t)
	if hold <= 0.0:
		return w.interaction._perform(t, p, GameConst.Verb.USE, 0.0)
	var ok := false
	var tt := 0.0
	while tt < hold:
		ok = w.interaction._perform(t, p, GameConst.Verb.USE, 1.0 / 60.0) or ok
		tt += 1.0 / 60.0
	return ok


## The starting kitchens have no dishwasher any more (you buy one): swap the
## counter where it used to stand for one.
func dishwasher() -> Fixture:
	var dw := fixture(&"dishwasher")
	if dw:
		return dw
	var cell := Vector2i(12, 8)
	var old := w.grid.fixture_at(cell)
	var rot := old.rot if old else 2
	if old:
		w.despawn(old)
	return w.spawn_fixture(&"dishwasher", cell, rot)


## A free dining-room cell away from tables and chairs (so nothing gets boxed in).
func free_dining_cell(def_id: StringName, skip: Array = []) -> Vector2i:
	var def := Content.fixture(def_id)
	for y in range(-2, 30):
		for x in range(-2, 40):
			var c := Vector2i(x, y)
			if c in skip or not w.grid.is_customer_area(c) or not w.grid.can_place(c, def):
				continue
			var near := false
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var n := w.grid.fixture_at(c + Vector2i(dx, dy))
					if n and n.def and n.def.id in [&"table", &"chair"]:
						near = true
			if not near:
				return c
	return Vector2i(-999, -999)


## Presses GRAB through the real input path and holds it for `sec`.
func press_grab(sec: float) -> void:
	p.input_override = true
	p.set_input(Vector2.ZERO, false, false, false, false)
	await frames(3)   # let targeting catch up with a teleported player
	p.set_input(Vector2.ZERO, true, false, false, false)
	await wait(sec)
	p.set_input(Vector2.ZERO, false, false, false, false)
	await frames(2)
	p.input_override = false


func held_id() -> String:
	return String(p.held().def_id) if p.held() else ""


# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

func t_layout() -> void:
	print("[layout]")
	check(w.grid.rooms.size() == 4, "four starting rooms")
	check(w.grid.all_fixtures().size() >= 55, "fixtures spawned (%d)" % w.grid.all_fixtures().size())
	check(w.customers.total_seats() == 16, "16 seats across the dining room (%d)" % w.customers.total_seats())
	check(w.grid.nav.reachable(Vector2i(4, 10), Vector2i(2, 1)), "customers can path from the street to a chair")
	check(w.day.phase == GameConst.Phase.MORNING, "game starts in morning prep")
	check(w.grid.fixtures_of(&"dishwasher").is_empty(), "no dishwasher at the start (you buy one)")
	check(w.all_of_kind(&"plot").size() == 4, "four expansion plots for sale")
	var from := GameConst.world_to_cell(p.global_position)
	var signs_ok := true
	for pl in w.all_of_kind(&"plot"):
		var at := GameConst.world_to_cell((pl as Node3D).global_position)
		if not w.grid.nav.reachable(from, at) or w.grid.is_building(at):
			signs_ok = false
	check(signs_ok, "every FOR SALE sign is outside and walkable from the kitchen")


func t_difficulty() -> void:
	print("[difficulty]")
	check(Difficulty.level() == Difficulty.NORMAL, "default difficulty is Normal")
	# Plan the same day at each level, then put today's plan back.
	var cm := w.customers
	var saved := [cm.schedule.duplicate(true), cm.forecast.duplicate(), cm._sched_i]
	var counts := []
	var rush_ok := true
	for lvl in [Difficulty.RELAXED, Difficulty.NORMAL, Difficulty.HECTIC]:
		Settings._values["difficulty"] = lvl   # (not saved to disk)
		cm.plan_day(4, 2.5)
		counts.push_back(cm.schedule.size())
		# Every rush hour is at least as busy as every quiet hour.
		var rush := cm.rush_hours()
		for h in cm.forecast:
			for r in rush:
				if not h in rush and int(cm.forecast.get(r, 0)) < int(cm.forecast[h]):
					rush_ok = false
	Settings._values["difficulty"] = Difficulty.NORMAL
	cm.schedule = saved[0]
	cm.forecast = saved[1]
	cm._sched_i = saved[2]
	check(counts[0] < counts[1] and counts[1] < counts[2], "easier settings bring fewer guests %s" % str(counts))
	check(rush_ok, "rush hours always get the most guests")
	var easier := true
	for k in ["patience", "spoil"]:
		easier = easier and Difficulty.PRESETS[0][k] > Difficulty.PRESETS[1][k] and Difficulty.PRESETS[1][k] > Difficulty.PRESETS[2][k]
	for k in ["groups", "overcook", "disasters", "rep_loss"]:
		easier = easier and Difficulty.PRESETS[0][k] < Difficulty.PRESETS[1][k] and Difficulty.PRESETS[1][k] < Difficulty.PRESETS[2][k]
	check(easier, "every preset factor is ordered Relaxed < Normal < Hectic")


## Drives the player with simulated stick/button input and checks that the
## real targeting picks the station in front of them.
func t_input_targeting() -> void:
	print("[input & targeting]")
	var board := fixture(&"cutting_board", 0)
	p.input_override = true
	p.global_position = GameConst.cell_center(board.front_cell()) + Vector3(0, 0, 0.6)
	p.rotation.y = 0.0
	# Walk "up" (toward -Z) for a short while.
	for i in 30:
		p.set_input(Vector2(0, -1), false, false, false, false)
		await frames(1)
	p.set_input(Vector2.ZERO, false, false, false, false)
	await frames(10)
	check(p.facing.z < -0.9, "player turned to face up the screen")
	var t := w.interaction.target_of(p)
	check(t == board, "targeting picks the cutting board in front (%s)" % (t.display_name() if t else "none"))
	# During prep, GRAB on the empty board with empty hands picks the board
	# up (like PlateUp); a second press puts it back where it was.
	var board_cell := board.cell
	check(w.interaction.hint_for(p).get("grab", "") == "Move", "the hint offers to move the empty board")
	p.set_input(Vector2.ZERO, true, false, false, false)
	await frames(2)
	p.set_input(Vector2.ZERO, false, false, false, false)
	await frames(2)
	check(p.held() == null and p.carried_fixture == board, "one press picks up the empty board")
	p.set_input(Vector2.ZERO, true, false, false, false)
	await frames(2)
	p.set_input(Vector2.ZERO, false, false, false, false)
	await frames(2)
	check(p.carried_fixture == null and board.cell == board_cell, "and a second press puts it back")
	var h := w.interaction.hint_for(p)
	check(h.get("target") == board, "hint describes the board")
	p.input_override = false
	# Reaching through a wall: stand in the dining room against the kitchen
	# wall, facing a kitchen counter on the other side.
	var behind: Fixture = null
	for f in w.grid.all_fixtures():
		var c: Vector2i = f.cell
		var other := c + Vector2i(-1, 0)
		if f.def.category != "seating" and w.grid.wall_between(c, other) and w.grid.room_index(other) >= 0 and w.grid.fixture_at(other) == null:
			behind = f
			break
	if behind:
		var bait: Item = null
		if behind.primary_slot() and behind.primary_slot().item == null:
			bait = w.spawn_item(&"dishware", {"p": 1}, {"slot": [behind.net_id, 0]})
		var stand := GameConst.cell_center(behind.cell + Vector2i(-1, 0)) + Vector3(0.3, 0, 0)
		p.global_position = stand
		p.rotation.y = PI * 0.5
		p.facing = Vector3(1, 0, 0)
		check(w.interaction.find_target(p) != behind, "can't reach the %s through the wall" % behind.display_name())
		p.global_position = GameConst.cell_center(behind.front_cell())
		var to := behind.global_position - p.global_position
		p.facing = Vector3(to.x, 0, to.z).normalized()
		check(w.interaction.find_target(p) == behind, "but can from its own side")
		if bait:
			w.despawn(bait)
	else:
		check(false, "found a fixture against a wall to test reaching through")


func t_delivery() -> void:
	print("[delivery]")
	await wait(13.0)
	var crates := []
	for it in w.items_root.get_children():
		if it is CrateItem:
			crates.push_back(it)
	check(crates.size() >= 6, "morning truck dropped crates on the dock (%d)" % crates.size())
	var beef: CrateItem = null
	for c in crates:
		if (c as CrateItem).content_id == &"patty":
			beef = c
	check(beef != null, "beef crate delivered")
	if beef:
		grab(beef)
		check(p.held() == beef, "picked up the beef crate")
		var counter := fixture(&"counter", 3)
		grab(counter)
		check(beef.slot != null and beef.slot.owner_entity == counter, "placed crate on a counter")
		use(counter)
		check(held_id() == "patty", "took a patty out of the crate with USE")
		grab(counter)
		check(p.held() == null and beef.count == 12, "put the patty back into the crate")
		check(not beef.is_cold(), "crate on a counter is not cold")


func t_prep_and_cook() -> void:
	print("[prep & cook]")
	var potatoes: CrateItem = fixture(&"shelf", 0).primary_slot().item
	check(potatoes != null and potatoes.content_id == &"potato", "potato sack on the first shelf")
	use(fixture(&"shelf", 0))
	check(held_id() == "potato", "took a potato")
	var board := fixture(&"cutting_board", 0)
	grab(board)
	check(board.primary_slot().item != null, "potato on the cutting board")
	use(board, 2.5)
	var cut: Item = board.primary_slot().item
	check(cut != null and cut.def_id == &"fries", "chopping turns a potato into fries")
	grab(board)
	check(held_id() == "fries", "picked up raw fries")
	var fryer := fixture(&"fryer")
	grab(fryer)
	var fries: FoodItem = fryer.primary_slot().item
	check(fries != null, "fries in the fryer")
	await wait(6.0)
	check(fries.cook > 0.4, "fryer cooks over time (%.2f)" % fries.cook)
	var stage := fries.def.cook_profile.stage_name(fries.cook)
	print("     fries stage: ", stage)
	# Stock the fridge with the delivered beef, then grill a patty from it
	var beef: CrateItem = null
	for it in w.items_in_world():
		if it is CrateItem and (it as CrateItem).content_id == &"patty":
			beef = it
	grab(beef)
	grab(fixture(&"fridge", 0))
	check(beef.slot != null and beef.slot.owner_entity == fixture(&"fridge", 0) and beef.is_cold(), "beef crate stored cold in the fridge")
	use(fixture(&"fridge", 0))
	check(held_id() == "patty", "patty from the fridge crate")
	var grill := fixture(&"grill", 0)
	grab(grill)
	var patty: FoodItem = grill.primary_slot().item
	check(patty != null, "patty on the grill")
	await wait(9.5)
	check(patty.def.cook_profile.stage_index(patty.cook) >= 1, "patty cooking (%s)" % patty.def.cook_profile.stage_name(patty.cook))


func t_plating_and_coffee() -> void:
	print("[plating & coffee]")
	var rack := fixture(&"plate_rack")
	var before := (rack.get_component("DishRack") as DishRack).count
	grab(rack)
	check(p.held() is DishItem and (p.held() as DishItem).plates == 1, "took a clean plate")
	check((rack.get_component("DishRack") as DishRack).count == before - 1, "rack count decreased")
	# Plate + fries from the fryer
	var fryer := fixture(&"fryer")
	grab(fryer)
	var plate := p.held() as DishItem
	check(plate != null and plate.content_ids().has(&"fries"), "plate picked up the fries from the fryer")
	var r := plate.recipe() if plate else null
	check(r != null and r.id == &"fries", "plate matches the Fries recipe")
	var counter := fixture(&"counter", 1)
	grab(counter)
	# Burger: bun + patty on a fresh plate
	grab(rack)
	var plate2 := p.held() as DishItem
	var c2 := fixture(&"counter", 2)
	grab(c2)
	var bun_shelf: Fixture = null
	for sh in w.grid.fixtures_of(&"shelf"):
		var it = sh.primary_slot().item
		if it is CrateItem and it.content_id == &"bun":
			bun_shelf = sh
	grab(c2)
	check(p.held() == plate2, "picked the plate back up")
	use(bun_shelf)
	check(plate2.content_ids().has(&"bun"), "USE on the bun crate while holding a plate adds a bun")
	grab(c2)
	var grill := fixture(&"grill", 0)
	await wait(2.0)
	grab(grill)
	check(held_id() == "patty", "took the patty off the grill")
	grab(c2)
	check(plate2.recipe() != null and plate2.recipe().id == &"burger", "bun + patty = Classic Burger")
	print("     burger quality: %.2f" % plate2.quality())
	# Holding food, GRAB on the plate rack plates it in one go.
	var spare := w.spawn_item(&"fries", {"ck": 0.45})
	p.hold(spare)
	var rc := (rack.get_component("DishRack") as DishRack).count
	grab(rack)
	var plated := p.held() as DishItem
	check(plated != null and plated.content_ids().has(&"fries"), "holding fries, GRAB on the plate rack plates them")
	check((rack.get_component("DishRack") as DishRack).count == rc - 1, "and uses one plate from the rack")
	if plated:
		w.despawn(plated)
	# Coffee
	var mugs := fixture(&"mug_rack")
	grab(mugs)
	check(p.held() is DishItem and (p.held() as DishItem).is_mug(), "took a mug")
	var cm := fixture(&"coffee_machine")
	grab(cm)
	check(cm.primary_slot().item != null, "mug under the coffee machine")
	await wait(4.5)
	var mug := cm.primary_slot().item as DishItem
	check(mug != null and mug.content_ids().has(&"coffee"), "coffee brewed into the mug")
	grab(cm)
	check(p.held() == mug, "took the coffee")
	grab(fixture(&"counter", 0))


func t_build_mode() -> void:
	print("[build mode]")
	var f := fixture(&"counter", 4)
	var old_cell := f.cell
	approach(f)
	check(w.build.try_lift(p, f), "lifted a counter during prep")
	check(p.carried_fixture == f, "carrying the counter")
	w.build.rotate_carried(p)
	# Place it two cells into the storage room floor
	p.global_position = GameConst.cell_center(Vector2i(17, 3)) + Vector3(0, 0, 0)
	p.rotation.y = 0.0
	p.facing = Vector3(0, 0, 1)
	var placed := w.build.try_place_carried(p)
	check(placed and f.cell == Vector2i(17, 4), "placed it on a new cell (%s)" % str(f.cell))
	check(w.grid.fixture_at(old_cell) == null, "old cell freed")
	w.build.drop_all_carried()
	# Real button presses: one tap picks up an empty counter...
	var c2 := f   # the counter just moved into the storage room: nothing next to it
	for sl in c2.slots:
		if sl.item:
			w.despawn(sl.item)
	await frames(1)
	approach(c2)
	await frames(3)
	check(w.interaction.target_of(p) == c2 and w.interaction.hint_for(p).get("grab", "") == "Move", "facing an empty counter, the hint says GRAB: Move")
	await press_grab(0.05)
	check(p.carried_fixture == c2, "one GRAB press picks up an empty counter")
	await press_grab(0.05)
	check(p.carried_fixture == null and not c2.lifted, "another press puts it down")
	# ...and holding GRAB moves one with something on it, the item riding along.
	approach(c2)
	var tom: Item = w.spawn_item(&"tomato", {}, {"slot": [c2.net_id, 0]})
	await frames(1)
	await press_grab(0.7)
	check(p.carried_fixture == c2 and p.held() == null, "holding GRAB lifts a counter that has a tomato on it")
	check(tom.slot != null and tom.slot.owner_entity == c2, "the tomato rides along on the counter")
	await press_grab(0.05)
	check(p.carried_fixture == null and tom.slot and tom.slot.owner_entity == c2, "put down with the tomato still on it")
	w.despawn(tom)


func t_service() -> void:
	print("[service]")
	# Nobody opens the doors: they open when prep time runs out.
	var sign0 := fixture(&"open_sign")
	approach(sign0)
	check(w.interaction._query(sign0, p, GameConst.Verb.USE).get("blocked", false), "the sign can't open early")
	w.day.auto_open = true
	w.day.prep_left = 1.0
	await wait(1.5)
	check(w.day.phase == GameConst.Phase.SERVICE, "the doors opened by themselves")
	check(w.day.phase == GameConst.Phase.SERVICE, "restaurant opened")
	check(w.customers.groups.size() >= 1, "the first guests were already waiting at the door")
	var g := w.customers.spawn_group(Content.archetype(&"traveler"), true)
	check(g != null and g.members.size() == 1, "spawned a tired traveler")
	var t := 0.0
	while g.state != CustomerGroup.State.READY and t < 40.0:
		await wait(0.5)
		t += 0.5
	check(g.state == CustomerGroup.State.READY, "customer walked in, sat down and is ready to order (%s)" % CustomerGroup.State.keys()[g.state])
	if g.state != CustomerGroup.State.READY:
		return
	var table: Fixture = g.tables[0]
	use(table)
	check(g.state == CustomerGroup.State.WAITING_FOOD, "took the order")
	check(w.orders.orders.size() >= 1, "order ticket created")
	var m := g.members[0]
	for o in m.orders:
		var r := Content.recipe(o["recipe"])
		var dish := _make_perfect(r, o.get("extras", []))
		p.hold(dish)
		var ok := grab(table)
		check(ok, "served %s" % r.display_name)
	check(g.state == CustomerGroup.State.EATING, "customer is eating")
	t = 0.0
	while g.state != CustomerGroup.State.GONE and g.state != CustomerGroup.State.LEAVING and t < 60.0:
		await wait(0.5)
		t += 0.5
	check(g.state == CustomerGroup.State.LEAVING or g.state == CustomerGroup.State.GONE, "customer paid and left")
	check(w.day.stats["revenue"] > 0.0, "revenue recorded (%.2f)" % w.day.stats["revenue"])
	var st := table.get_component("SeatingTable") as SeatingTable
	check(st.has_dirty_dishes(), "dirty dishes left on the table")
	grab(table)
	check(p.held() is DishItem and (p.held() as DishItem).dirty, "cleared the dirty dishes")


func _make_perfect(r: RecipeDef, extras: Array = []) -> DishItem:
	var contents := []
	for id in r.required + extras:
		var d := Content.item(id)
		var ck := 0.0
		if d.cook_profile:
			var pr := d.cook_profile
			ck = (pr.stage_ends[pr.perfect_stage - 1] + pr.stage_ends[pr.perfect_stage]) * 0.5
		contents.push_back({"id": String(id), "ck": ck})
	return w.spawn_item(&"dishware", {"p": 0 if r.container == "mug" else 1, "m": 1 if r.container == "mug" else 0, "c": contents}) as DishItem


func t_dishes() -> void:
	print("[dishes]")
	var sink := fixture(&"sink")
	var s := sink.get_component("Sink") as Sink
	check(p.held() is DishItem, "holding dirty dishes")
	grab(sink)
	check(s.dirty_total() > 0 and p.held() == null, "dishes in the sink")
	var n := s.dirty_total()
	use(sink, n * 1.4 + 0.3)
	check(s.dirty_total() == 0 and s.clean_total() == n, "washed everything (%d clean)" % s.clean_total())
	grab(sink)
	check(p.held() is DishItem and not (p.held() as DishItem).dirty, "took clean dishes")
	var pile := p.held() as DishItem
	if pile.plates > 0:
		grab(fixture(&"plate_rack"))
	if p.held() and (p.held() as DishItem).mugs > 0:
		grab(fixture(&"mug_rack"))
	check(p.held() == null, "put clean dishes away")


func t_disasters() -> void:
	print("[disasters]")
	var grill := fixture(&"grill", 1)
	var fl := grill.get_component("Flammable") as Flammable
	fl.ignite()
	check(fl.burning, "grease fire started")
	var station := fixture(&"extinguisher_station")
	grab(station)
	check(held_id() == "extinguisher", "grabbed the extinguisher")
	approach(grill)
	var t := 0.0
	while fl.burning and t < 5.0:
		w.disasters.use_tool(p, p.held(), 1.0 / 30.0)
		t += 1.0 / 30.0
	check(not fl.burning, "fire extinguished in %.1fs" % t)
	grab(station)
	var dw := dishwasher()
	var br := dw.get_component("Breakable") as Breakable
	br.break_down()
	check(not dw.is_working(), "dishwasher broke down")
	use(dw, 4.0)
	check(dw.is_working(), "repaired the dishwasher")
	var rep_before := w.economy.reputation
	w.disasters.trigger(&"health_inspection")
	await wait(1.0)
	var inspectors := w.all_of_kind(&"customer").filter(func(c): return c.def_id == &"inspector")
	check(inspectors.size() == 1, "a health inspector walked in")
	await wait(27.0)
	check(not is_equal_approx(w.economy.reputation, rep_before), "inspection graded the restaurant (rep %.2f → %.2f)" % [rep_before, w.economy.reputation])
	# Walking out takes a little while (other guests may be in the doorway).
	var tw := 0.0
	while tw < 30.0 and not w.all_of_kind(&"customer").filter(func(c): return c.def_id == &"inspector").is_empty():
		await wait(1.0)
		tw += 1.0
	check(w.all_of_kind(&"customer").filter(func(c): return c.def_id == &"inspector").is_empty(), "the inspector left")
	w.disasters.trigger(&"power_outage")
	check(not fixture(&"grill", 0).is_working() and not fixture(&"fridge", 0).is_cooling(), "power cut stops powered machines")
	check(fixture(&"counter", 0).is_working(), "unpowered fixtures still work")
	await wait(17.0)
	check(fixture(&"grill", 0).is_working(), "power comes back")
	var spill := w.disasters.spawn_mess(&"spill", GameConst.cell_center(Vector2i(12, 6)))
	check(spill != null and w.disasters.is_slippery(spill.global_position), "spill is slippery")
	grab(fixture(&"mop_station"))
	check(held_id() == "mop", "grabbed the mop")
	p.global_position = spill.global_position - Vector3(0, 0, 0.6)
	p.facing = Vector3(0, 0, 1)
	t = 0.0
	while is_instance_valid(spill) and spill.is_inside_tree() and t < 4.0:
		w.disasters.use_tool(p, p.held(), 1.0 / 30.0)
		t += 1.0 / 30.0
		await frames(1)
	check(not is_instance_valid(spill) or not spill.is_inside_tree(), "mopped up the spill")
	grab(fixture(&"mop_station"))


func t_staff() -> void:
	print("[staff]")
	w.economy.earn(200.0, "test")
	check(w.staff.hire(&"dish_hand"), "hired a dish hand")
	var worker := w.staff.workers()[0] as Worker
	check(worker != null and worker.role == &"dishwasher", "worker spawned with the dishwasher role")
	var sink := fixture(&"sink")
	var s := sink.get_component("Sink") as Sink
	s.dirty_plates += 3
	sink.mark_dirty()
	var t := 0.0
	while (s.dirty_total() > 0 or s.clean_total() > 0 or worker.held() != null) and t < 45.0:
		await wait(0.5)
		t += 0.5
	check(s.dirty_total() == 0, "the dish hand washed the dirty plates (%.0fs)" % t)
	check(s.clean_total() == 0 and worker.held() == null, "and put them away")
	w.staff.dismiss(worker)
	check(w.staff.workers().is_empty(), "dismissed the worker")


func t_automation() -> void:
	print("[automation]")
	# Grabber pulls potatoes out of a crate on a counter and a conveyor carries
	# them onto another counter.
	var cells := [Vector2i(17, 2), Vector2i(17, 3), Vector2i(17, 4), Vector2i(17, 5)]
	for c in cells:
		var f := w.grid.fixture_at(c)
		if f:
			w.despawn(f)
	var src := w.spawn_fixture(&"counter", Vector2i(17, 2), 0)
	var grabber := w.spawn_fixture(&"grabber", Vector2i(17, 3), 0)
	var belt := w.spawn_fixture(&"conveyor", Vector2i(17, 4), 0)
	var dst := w.spawn_fixture(&"counter", Vector2i(17, 5), 0)
	check(src != null and grabber != null and belt != null and dst != null, "built a grabber → conveyor line")
	var crate := w.spawn_crate(&"supply_potatoes", 3, {"slot": [src.net_id, 0]})
	var t := 0.0
	while dst.primary_slot().item == null and t < 20.0:
		await wait(0.5)
		t += 0.5
	var got: Item = dst.primary_slot().item
	check(got != null and got.def_id == &"potato", "a potato travelled down the line (%.1fs)" % t)
	check(crate.count < 3, "the grabber took it out of the crate")
	for f in [src, grabber, belt, dst]:
		w.despawn(f)


func t_regressions() -> void:
	print("[regressions]")
	if p.held():
		w.despawn(p.held())
	# A blocked station refuses (real GRAB press) instead of swallowing the pile.
	var dwf := dishwasher()
	var dw := dwf.get_component("Dishwasher") as Dishwasher
	dw.state = Dishwasher.State.LOADING
	dw.plates = dw.capacity - 2
	dw.mugs = 0
	var pile := w.spawn_item(&"dishware", {"p": 4, "dt": true})
	p.hold(pile)
	approach(dwf)
	p.input_override = true
	p.set_input(Vector2.ZERO, true, false, false, false)
	await frames(2)
	p.set_input(Vector2.ZERO, false, false, false, false)
	await frames(2)
	p.input_override = false
	check(p.held() == pile and pile.plates == 4, "a full dishwasher refuses the pile (still in hand)")
	check(dw.plates == dw.capacity - 2, "and the dishwasher count is unchanged")
	w.despawn(pile)
	dw.plates = 0
	dwf.mark_dirty()
	# Tall dirty stacks topple when walked around; small ones never do.
	var small := w.spawn_item(&"dishware", {"p": 4, "dt": true})
	p.hold(small)
	var fell := false
	var start := p.global_position
	for i in 1800:
		p.global_position = start + Vector3(0.075 * (i % 40), 0, 0)
		w.interaction._check_stack(p, 1.0 / 60.0)
		if p.held() != small:
			fell = true
			break
	check(not fell, "a pile of 4 dirty plates is steady")
	if p.held():
		w.despawn(p.held())
	var tall := w.spawn_item(&"dishware", {"p": 10, "dt": true})
	p.hold(tall)
	var shards_before := 0
	for m in get_tree().get_nodes_in_group(&"messes"):
		if (m as Mess).def_id == &"shards":
			shards_before += 1
	fell = false
	for i in 1800:
		p.global_position = start + Vector3(0.075 * (i % 40), 0, 0)
		w.interaction._check_stack(p, 1.0 / 60.0)
		if p.held() != tall:
			fell = true
			break
	await frames(2)
	var shards_after := 0
	for m in get_tree().get_nodes_in_group(&"messes"):
		if (m as Mess).def_id == &"shards":
			shards_after += 1
	check(fell, "a pile of 10 dirty plates topples while walking")
	check(shards_after > shards_before, "and leaves broken dishes on the floor")
	check(not is_instance_valid(tall) or tall.is_queued_for_deletion() or tall.count() < 10, "some of the plates broke")
	if is_instance_valid(tall) and not tall.is_queued_for_deletion():
		w.despawn(tall)
	for m in get_tree().get_nodes_in_group(&"messes"):
		if (m as Mess).def_id == &"shards":
			w.despawn(m)
	p.global_position = start
	# Automation: a partial rack insert hands the remainder back to the belt.
	var rack := fixture(&"plate_rack")
	var dr := rack.get_component("DishRack") as DishRack
	var before := dr.count
	dr.count = dr.capacity - 2
	var clean := w.spawn_item(&"dishware", {"p": 5, "dt": false})
	clean.detach()   # as a belt or grabber does before handing over
	var took := Automation.try_insert(rack, clean)
	check(not took and is_instance_valid(clean) and clean.plates == 3, "a nearly full rack hands back what doesn't fit")
	check(dr.count == dr.capacity, "and keeps what does")
	w.despawn(clean)
	dr.count = before
	rack.mark_dirty()


func t_round5() -> void:
	print("[round 5]")
	var cm := w.customers
	# Joined tables share one colour; separate tables get their own.
	var joined := 0
	var same := true
	var nums := {}
	for c in cm.clusters():
		var first := -1
		for tf in c["tables"]:
			var n := (tf.get_component("SeatingTable") as SeatingTable).number
			if first < 0:
				first = n
			elif n != first:
				same = false
		if c["tables"].size() > 1:
			joined += 1
		nums[first] = true
	check(same and nums.size() == cm.clusters().size(), "each set of joined tables has one colour (%d joined sets)" % joined)
	# Decor in the dining room does something (like PlateUp's furniture).
	var used := []
	for pair in [[&"painting", "tips"], [&"rug", "tidy"], [&"plant_pot", "patience"], [&"jukebox", "eat_speed"]]:
		var before := cm.decor_bonus(pair[1])
		var c := free_dining_cell(pair[0], used)
		used.push_back(c)
		var f := w.spawn_fixture(pair[0], c, 0)
		var after := cm.decor_bonus(pair[1])
		check(f != null and after > before, "%s: %s %.2f → %.2f" % [pair[0], pair[1], before, after])
		if f:
			w.despawn(f)
	await frames(2)
	check(cm.decor_bonus("tidy") <= CustomerManager.DECOR_CAP["tidy"], "decor bonuses are capped")
	# A waiting bench: the first in line sit on it and keep their patience.
	var seats_before := cm.total_seats()
	var bench := w.spawn_fixture(&"waiting_bench", free_dining_cell(&"waiting_bench"), 0)
	cm.mark_tables_dirty()
	check(bench != null and cm.bench_seats().size() == 2, "a waiting bench has two seats")
	check(cm.total_seats() == seats_before, "the bench doesn't block any chairs")
	var held_tables := []
	for c in cm.clusters():
		for t in c["tables"]:
			if not cm._reserved.has(t):
				cm._reserved[t] = null
				held_tables.push_back(t)
	var g := cm.spawn_group(Content.archetype(&"traveler"), true)
	var tw := 0.0
	while g and not (g.members[0].has_meta(&"bench") and g.members[0].seated) and tw < 40.0:
		await wait(0.5)
		tw += 0.5
	check(g != null and g.members[0].has_meta(&"bench") and g.members[0].seated, "a guest in line sat on the bench (%.0fs)" % tw)
	if g:
		check(is_equal_approx(cm.queue_patience_factor(g), CustomerManager.BENCH_PATIENCE), "sitting guests lose patience more slowly")
	for t in held_tables:
		cm._reserved.erase(t)
	tw = 0.0
	while g and g.state == CustomerGroup.State.QUEUED and tw < 20.0:
		await wait(0.5)
		tw += 0.5
	check(g != null and g.state != CustomerGroup.State.QUEUED and not g.members[0].has_meta(&"bench"), "and leaves the bench for a table")
	if g:
		cm.drop_group(g)
	w.despawn(bench)
	cm.mark_tables_dirty()
	await frames(2)
	# Safety grill: holds a patty at medium, never burns, never catches fire.
	var g0 := fixture(&"grill", 0)
	var gcell := g0.cell
	var grot := g0.rot
	w.despawn(g0)
	await frames(1)
	var sg := w.spawn_fixture(&"safety_grill", gcell, grot)
	var patty: FoodItem = w.spawn_item(&"patty", {"ck": 0.9}, {"slot": [sg.net_id, 0]})
	await wait(14.0)
	var prof := Content.item(&"patty").cook_profile
	check(prof.stage_index(patty.cook) == prof.perfect_stage, "the safety grill holds a patty at %s (%s)" % [prof.stage_names[prof.perfect_stage], prof.stage_name(patty.cook)])
	check(sg.get_component("Flammable") == null and not sg.def.flammable, "a safety grill can't catch fire")
	patty.cook = 1.4
	await wait(2.0)
	check(is_equal_approx(patty.cook, 1.4), "but it doesn't un-burn an overcooked patty (%.2f)" % patty.cook)
	w.despawn(patty)
	w.despawn(sg)
	await frames(1)
	w.spawn_fixture(&"grill", gcell, grot)
	# Fire sprinkler: puts out a nearby fire by itself (and leaves a puddle).
	var g1 := fixture(&"grill", 1)
	var spr_def := Content.fixture(&"sprinkler")
	var spr: Fixture = null
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var c := g1.cell + Vector2i(dx, dy)
			if spr == null and Vector2(dx, dy).length() < 3.0 and w.grid.can_place(c, spr_def):
				spr = w.spawn_fixture(&"sprinkler", c, 0)
	check(spr != null, "placed a fire sprinkler near the grills")
	var messes_before := get_tree().get_nodes_in_group(&"messes").size()
	var fl := g1.get_component("Flammable") as Flammable
	fl.ignite()
	tw = 0.0
	while fl.burning and tw < 10.0:
		await wait(0.5)
		tw += 0.5
	check(not fl.burning, "the sprinkler put the fire out (%.1fs)" % tw)
	await frames(2)
	var new_messes := get_tree().get_nodes_in_group(&"messes").slice(messes_before)
	check(not new_messes.is_empty(), "and left a puddle to mop")
	for m in new_messes:
		w.despawn(m)
	if spr:
		w.despawn(spr)
	# Readability: cold goods in silver coolers, drinks in their own glasses.
	var cold_ok := true
	for sd in Content.supplies.values():
		if sd.needs_cold != (sd.container == "crate_cold"):
			cold_ok = false
	check(cold_ok, "every chilled supply (and only those) comes in a silver cooler")
	check(DishPlating.vessel_key([{"id": &"beer"}]) == &"beer_pint" and DishPlating.vessel_key([{"id": &"soda"}]) == &"soda_glass", "beer and soda come in their own glasses")
	check(DishPlating.vessel_key([{"id": &"coffee"}]) == &"mug" and DishPlating.cup == &"mug", "coffee (and the diner's empty cups) are mugs")
	# The recipe book: a card per dish, each ingredient's journey as pictures.
	var rb := w.hud.recipe_book
	rb.open()
	check(rb.visible and rb._grid.get_child_count() == rb._menu().size() and rb._grid.get_child_count() > 0, "the recipe book has a card for each dish on the menu (%d)" % rb._grid.get_child_count())
	rb.close()
	var icons := func(id: StringName) -> Array:
		var out := []
		for row in RecipeBook.recipe_rows(Content.recipe(id)):
			for st in row["steps"]:
				out.push_back(st.get("icon", ""))
		return out
	check(icons.call(&"burger").has("station:grill") and icons.call(&"burger").has("cooked:patty"), "burger card: raw patty › grill › cooked patty")
	check(icons.call(&"fries").has("item:potato") and icons.call(&"fries").has("station:cutting_board") and icons.call(&"fries").has("station:fryer"), "fries card: potato › chop › fry")
	check(icons.call(&"croissant").has("station:oven"), "croissant card says bake it")
	check(icons.call(&"muffin").filter(func(k): return String(k).begins_with("station:")).is_empty(), "muffin card: no cooking")
	check(icons.call(&"pizza").has("model:plate") and icons.call(&"pizza").has("station:oven"), "pizza card: build on a plate, then bake")
	check(icons.call(&"beer").has("station:beer_tap") and icons.call(&"beer").has("model:glass"), "beer card: clean glass › beer tap")
	var croissant := Content.item(&"croissant").cook_profile
	check(croissant.color_at(0.0).get_luminance() > croissant.color_at(0.75).get_luminance() + 0.15, "raw croissants look clearly paler than baked ones")


func t_menu_board() -> void:
	print("[menu board & exact orders]")
	var board := fixture(&"menu_board")
	check(board != null, "the menu board stands in the dining room")
	if board:
		check(board.interact_query(p, GameConst.Verb.USE).get("label", "") == "Change the menu", "USE on the board edits the menu")
	check(Content.base_ingredient(&"tomato_sliced") == &"tomato" and Content.base_ingredient(&"fries") == &"potato" and Content.base_ingredient(&"coffee") == &"coffee_beans", "dish parts map to raw ingredients")
	# Exact orders: the extras a guest picked must be on the plate.
	var order := {"recipe": &"burger", "extras": [&"tomato_sliced"]}
	var with_tomato := _make_perfect(Content.recipe(&"burger"), [&"tomato_sliced"])
	var plain := _make_perfect(Content.recipe(&"burger"))
	check(RecipeManager.is_exact(order, with_tomato), "a burger with tomato matches 'burger + tomato'")
	check(RecipeManager.extras_diff(order, plain)["missing"] == [&"tomato_sliced"], "a plain burger is missing the tomato")
	check(RecipeManager.order_code(order) == "burger+tomato_sliced" and RecipeManager.parse_code("burger+tomato_sliced")["extras"] == [&"tomato_sliced"], "order codes round-trip")
	w.despawn(with_tomato)
	w.despawn(plain)
	# Cross tomatoes off: no salads, no tomato extras, and some guests mind.
	w.orders.set_struck(&"tomato", true)
	var a := Content.archetype(&"business")
	var salads := 0
	var tomato := 0
	var sad := 0
	for i in 300:
		var res := w.customers.choose_orders(a, false)
		if res["penalty"] > 0.0:
			sad += 1
		for o in res["orders"]:
			if o["recipe"] == &"salad":
				salads += 1
			if (o["extras"] as Array).has(&"tomato_sliced"):
				tomato += 1
	check(salads == 0 and tomato == 0, "with tomatoes crossed off nobody orders salad or tomato")
	check(sad > 0, "guests who wanted tomato are disappointed (%d of 300)" % sad)
	var saved := w.make_save()
	check((saved["menu"]["struck"] as Array).has("tomato"), "the menu is saved")
	w.orders.set_struck(&"tomato", false)
	check(not w.orders.is_struck(&"tomato"), "tomatoes back on the menu")
	check(SeatingTable.name_of(1) == "Red" and SeatingTable.name_of(11) == "Red 2", "tables are named by colour")


func t_spoilage() -> void:
	print("[spoilage]")
	var crate := w.spawn_crate(&"supply_lettuce", 4, {"floor": [21.5, 0.0, 7.5, 0.0]})
	crate.spoil_time = Content.item(&"lettuce").spoil_seconds - 1.0
	await wait(2.0)
	check(crate.spoiled, "lettuce left on the dock spoiled")
	var cold := w.spawn_crate(&"supply_lettuce", 4, {"slot": [fixture(&"fridge", 1).net_id, 0]}) if fixture(&"fridge", 1).primary_slot().item == null else fixture(&"fridge", 1).primary_slot().item as CrateItem
	var before := cold.spoil_time
	await wait(2.0)
	check(cold.is_cold() and is_equal_approx(cold.spoil_time, before), "fridge stock doesn't warm up")
	w.despawn(crate)


func t_consequences() -> void:
	print("[consequences]")
	var rep := w.economy.reputation
	var lost_before := int(w.day.stats.get("groups_lost", 0))
	w.day.streak = 4
	var g := w.customers.spawn_group(Content.archetype(&"regular_folks"), true)
	check(g != null, "spawned a group to upset")
	if g:
		g._get_upset()
	check(w.economy.reputation < rep - 0.05, "a walkout costs reputation (%.2f -> %.2f)" % [rep, w.economy.reputation])
	check(int(w.day.stats.get("groups_lost", 0)) == lost_before + 1, "and counts as lost")
	check(w.day.streak == 0, "and ends the streak")
	w.day.streak = 3
	check(absf(w.day.tip_bonus() - 0.3) < 0.001, "a streak of 3 raises tips by 30%")
	w.day.streak = 0


func t_close_day() -> void:
	print("[closing]")
	w.debug_command("end_service", [])
	await wait(1.0)
	check(w.day.phase == GameConst.Phase.CLOSING, "closing time")
	w.customers.clear_all()
	await wait(0.5)
	check(w.day.can_finish_day(), "can finish the day once empty")
	check(w.day.phase == GameConst.Phase.CLOSING, "a moment to breathe before the day ends")
	await wait(3.5)
	var sign_f := fixture(&"open_sign")
	check(w.day.phase == GameConst.Phase.RESULTS, "the day ended by itself once the guests had gone")
	var r: Dictionary = w.day.last_results
	check(r.get("people_served", 0) >= 1, "results count served customers")
	check((r.get("goals", []) as Array).size() == 2, "two daily goals on the results")
	check(r.has("groups_tomorrow") and int(r["groups_tomorrow"]) >= 3, "results say how many guests come tomorrow")
	print("     results: ", JSON.stringify(r).substr(0, 300))
	w.day.continue_from_results()
	check(w.day.phase == GameConst.Phase.EVENING, "evening planning")
	var money_before := w.economy.money
	w.economy.earn(600.0, "test")
	check(w.build.buy_expansion(&"walk_in_cooler"), "built the walk-in cooler")
	check(w.grid.is_cold_cell(Vector2i(17, -3)), "cooler cells are cold")
	check(w.grid.nav.reachable(Vector2i(17, 2), Vector2i(17, -2)), "cooler reachable from storage")
	w.economy.earn(300.0, "test")
	check(w.build.buy_expansion(&"patio"), "built the patio")
	check(w.grid.wall_between(Vector2i(-3, 8), Vector2i(-3, 9)), "patio fence blocks the street")
	check(not w.grid.wall_between(Vector2i(-1, 4), Vector2i(0, 4)), "patio door opens to the dining room")
	check(w.grid.nav.reachable(w.grid.street_point("spawn_a"), Vector2i(-2, 4)), "patio reachable via the front door")
	check(w.build.buy_fixture(&"conveyor"), "ordered a conveyor")
	# Supplies: the truck only brings what's ordered; auto lines repeat.
	check(w.deliveries.ordered_crates() == 0, "nothing on tomorrow's order by default")
	w.deliveries.adjust_order(&"supply_beef", 1)
	w.deliveries.adjust_order(&"supply_buns", 1)
	w.deliveries.set_auto(&"supply_buns", true)
	var pending_before := w.deliveries.pending.size()
	use(sign_f, 1.0)
	check(w.day.phase == GameConst.Phase.MORNING and w.day.day == 2, "day 2 morning")
	var truck_items := []
	for d in w.deliveries.pending.slice(pending_before):
		if d["label"] == "Morning delivery":
			truck_items = d["items"]
	var kinds := []
	for it in truck_items:
		kinds.push_back(it.get("supply", ""))
	kinds.sort()
	check(kinds == ["supply_beef", "supply_buns"], "the morning truck brings exactly the order %s" % str(kinds))
	check(w.deliveries.order.get(&"supply_buns", 0) == 1 and not w.deliveries.order.has(&"supply_beef"), "auto lines stay on the order, one-offs are cleared")


func t_save_load() -> void:
	print("[save/load]")
	await wait(1.0)
	var n_before := w.entities.size()
	var fixtures_before := w.grid.all_fixtures().size()
	var money := w.economy.money
	check(Saves.save_game(w), "saved")
	var data := Saves.load_data()
	check(int(data.get("version", 0)) == GameConst.SAVE_VERSION, "save is versioned")
	main.start_offline(true)
	await wait(0.6)
	w = GameWorld.current
	p = w.players()[0]
	check(w.grid.all_fixtures().size() == fixtures_before, "fixtures restored (%d vs %d)" % [w.grid.all_fixtures().size(), fixtures_before])
	check(absf(w.economy.money - money) < 0.01, "money restored")
	check(&"walk_in_cooler" in w.grid.built_expansions, "expansion restored")
	check(w.day.day == 2, "day restored")
	print("     entities before %d after %d" % [n_before, w.entities.size()])
