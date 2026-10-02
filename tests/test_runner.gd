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
	await t_layout()
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
	await t_spoilage()
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
	check(w.all_of_kind(&"plot").size() == 4, "four expansion plots for sale")


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
	# Press GRAB on the empty board with empty hands: nothing to pick up, no crash.
	p.set_input(Vector2.ZERO, true, false, false, false)
	await frames(2)
	p.set_input(Vector2.ZERO, false, false, false, false)
	await frames(2)
	check(p.held() == null, "nothing picked up from an empty board")
	var h := w.interaction.hint_for(p)
	check(h.get("target") == board, "hint describes the board")
	p.input_override = false


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
	# Grill a patty from the fridge stock
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
	use(bun_shelf)
	check(held_id() == "bun", "took a bun")
	grab(c2)
	check(plate2.content_ids().has(&"bun"), "bun added to the plate on the counter")
	var grill := fixture(&"grill", 0)
	await wait(2.0)
	grab(grill)
	check(held_id() == "patty", "took the patty off the grill")
	grab(c2)
	check(plate2.recipe() != null and plate2.recipe().id == &"burger", "bun + patty = Classic Burger")
	print("     burger quality: %.2f" % plate2.quality())
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


func t_service() -> void:
	print("[service]")
	w.day.open_restaurant()
	check(w.day.phase == GameConst.Phase.SERVICE, "restaurant opened")
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
		var dish := _make_perfect(r)
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


func _make_perfect(r: RecipeDef) -> DishItem:
	var contents := []
	for id in r.required:
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
	var dw := fixture(&"dishwasher")
	var br := dw.get_component("Breakable") as Breakable
	br.break_down()
	check(not dw.is_working(), "dishwasher broke down")
	use(dw, 4.0)
	check(dw.is_working(), "repaired the dishwasher")
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


func t_close_day() -> void:
	print("[closing]")
	w.debug_command("end_service", [])
	await wait(1.0)
	check(w.day.phase == GameConst.Phase.CLOSING, "closing time")
	w.customers.clear_all()
	await wait(0.5)
	check(w.day.can_finish_day(), "can finish the day once empty")
	var sign_f := fixture(&"open_sign")
	use(sign_f, 1.0)
	check(w.day.phase == GameConst.Phase.RESULTS, "results screen")
	var r: Dictionary = w.day.last_results
	check(r.get("people_served", 0) >= 1, "results count served customers")
	print("     results: ", JSON.stringify(r).substr(0, 300))
	w.day.continue_from_results()
	check(w.day.phase == GameConst.Phase.EVENING, "evening planning")
	var money_before := w.economy.money
	w.economy.earn(600.0, "test")
	check(w.build.buy_expansion(&"walk_in_cooler"), "built the walk-in cooler")
	check(w.grid.is_cold_cell(Vector2i(17, -3)), "cooler cells are cold")
	check(w.grid.nav.reachable(Vector2i(17, 2), Vector2i(17, -2)), "cooler reachable from storage")
	check(w.build.buy_fixture(&"conveyor"), "ordered a conveyor")
	use(sign_f, 1.0)
	check(w.day.phase == GameConst.Phase.MORNING and w.day.day == 2, "day 2 morning")


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
