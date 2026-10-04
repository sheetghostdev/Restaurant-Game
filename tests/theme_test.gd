extends Node
## Headless test of the themed locations: the Dining Car Express (market
## stalls at stops, doors, leaving things behind) and the Orbital Galley
## (planters and the food printer).
## Run: godot --headless --path . res://tests/theme_test.tscn

var failures := 0
var checks := 0
var main: Node
var w: GameWorld
var p: PlayerCharacter
var _log: Array[String] = []


func _ready() -> void:
	Saves.active_slot = "theme_test"
	Saves.delete()
	Engine.time_scale = 4.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await t_new_game_screen()
	await t_train()
	if ResourceLoader.exists("res://data/layouts/space.json") or FileAccess.file_exists("res://data/layouts/space.json"):
		await t_space()
	print("")
	print("==== %d checks, %d failures ====" % [checks, failures])
	for l in _log:
		print(l)
	Saves.delete()
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures > 0 else 0)


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


func use(t: Node3D) -> bool:
	approach(t)
	return w.interaction._perform(t, p, GameConst.Verb.USE, 0.0)


func _start(loc: String, fmt: String) -> void:
	main.start_offline(false, {"location": loc, "format": fmt})
	await wait(0.6)
	w = GameWorld.current
	p = w.players()[0]


func stalls() -> Array:
	return w.grid.fixtures_of(&"market_stall")


# -----------------------------------------------------------------------------

func t_train() -> void:
	print("[train]")
	await _start("express", "diner")
	var tl := w.theme_node as TrainLine
	check(tl != null, "the train has a timetable")
	await wait(1.0)
	check(tl.state == TrainLine.State.STOPPED and tl.market_open, "waiting at the depot with the market open")
	var n_supplies := Content.supplies_for(w.format).size()
	check(stalls().size() == n_supplies, "depot sells every supply (%d stalls)" % stalls().size())
	check(not w.grid.locked.has("train_door"), "doors open at the depot")
	await wait(12.0)
	var crates := 0
	for it in w.loose_items():
		if it is CrateItem:
			crates += 1
	check(crates == 6, "free opening stock landed in the baggage car (%d)" % crates)
	# Buy a crate.
	var st: Fixture = stalls()[0]
	var ms := st.get_component("MarketStall") as MarketStall
	var money := w.economy.money
	var stock := ms.stock
	grab(st)
	check(p.held() is CrateItem, "bought a crate at the stall")
	check(absf(w.economy.money - (money - ms.price)) < 0.01, "paid %s for it" % GameConst.money(ms.price))
	check(ms.stock == stock - 1, "stall stock went down")
	# Leave it on the platform, stay outside, and let the train go.
	var crate := p.take_held()
	w.place_item(crate, {"floor": [10.5, 0.0, 7.5, 0.0]})
	p.global_position = Vector3(12.5, 0, 7.5)
	w.debug_command("start_service", [])
	await wait(0.5)
	check(tl.state == TrainLine.State.DEPARTING, "train departs when service starts")
	check(w.grid.locked.has("train_door"), "doors locked")
	check(w.grid.wall_between(Vector2i(18, 5), Vector2i(18, 6)), "the platform door is a wall now")
	check(stalls().is_empty(), "stalls packed up")
	check(not is_instance_valid(crate) or crate.is_queued_for_deletion(), "the crate on the platform was left behind")
	check(w.grid.is_inside(GameConst.world_to_cell(p.global_position)), "the player was hauled back aboard")
	await wait(6.0)
	check(tl.state == TrainLine.State.MOVING, "moving between stations")
	check(tl.status_line().begins_with("Next stop"), "HUD: %s" % tl.status_line())
	# Fast-forward to the first stop.
	w.day.elapsed = w.format.service_seconds * TrainLine.STOP_AT[0]
	var groups_before := w.customers.groups.size()
	await wait(1.0)
	check(tl.state == TrainLine.State.ARRIVING, "arriving at %s" % tl.station)
	await wait(TrainLine.SLIDE_TIME + 0.5)
	check(tl.state == TrainLine.State.STOPPED, "stopped")
	check(not w.grid.locked.has("train_door"), "doors open at the stop")
	var deals := 0
	for f in stalls():
		if (f.get_component("MarketStall") as MarketStall).tag == "deal":
			deals += 1
	check(stalls().size() >= 3 and stalls().size() <= 4, "a few stalls at the stop (%d)" % stalls().size())
	check(deals == 1, "one deal per stop")
	check(w.customers.groups.size() > groups_before, "passengers boarded (%d -> %d)" % [groups_before, w.customers.groups.size()])
	# Whistle, then off again.
	await wait(TrainLine.STOP_TIME - TrainLine.WHISTLE_AT + 1.0)
	check(tl.state == TrainLine.State.STOPPED, "still there after the whistle")
	await wait(TrainLine.WHISTLE_AT)
	check(tl.state == TrainLine.State.DEPARTING or tl.state == TrainLine.State.MOVING, "left the station")
	check(tl.stops_done == 1, "one stop done")
	# Evening: at the terminus with the doors open.
	w.debug_command("end_service", [])
	await wait(0.2)
	w.customers.clear_all()
	w.debug_command("end_service", [])
	await wait(0.5)
	check(tl.state == TrainLine.State.STOPPED and not w.grid.locked.has("train_door"), "at the terminus for the night")
	check(stalls().is_empty(), "no market at night")
	w.debug_command("end_service", [])
	await wait(0.5)
	w.debug_command("start_service", [])   # evening -> next morning
	await wait(1.5)
	check(w.day.day == 2 and tl.market_open, "day 2 starts at the depot market")
	var delivered := 0
	await wait(4.0)
	for it in w.loose_items():
		if it is CrateItem and GameConst.world_to_cell((it as CrateItem).global_position) in w.grid.delivery_zone:
			delivered += 1
	check(w.deliveries.order.is_empty(), "nothing ordered from a truck on the train")


func t_new_game_screen() -> void:
	print("[new game screen]")
	main.show_menu()
	await wait(0.3)
	var menu: MainMenu = main.menu
	menu._new_game()
	await wait(0.2)
	var panel := menu._new_panel
	check(panel.visible, "New Restaurant opens the picker")
	panel._pick_location(&"express")
	panel._pick_format(&"bar")
	check(panel._name.text == "The Tipsy Tap", "the name follows the restaurant type")
	panel._name.text = "Rolling Tap"
	panel._go(false)
	await wait(0.8)
	w = GameWorld.current
	check(w != null and w.location.id == &"express" and w.format.id == &"bar", "opened a bar on the train")
	check(w != null and w.restaurant_name == "Rolling Tap", "with the chosen name")
	check(w != null and Content.menu_ingredients(w.format).has(&"keg"), "serving beer")


func t_space() -> void:
	print("[space]")
	await _start("orbital", "diner")
	check(w.theme_node is SpaceOrbit and w.lighting.space, "in orbit, with space lighting")
	var planters := w.grid.fixtures_of(&"hydro_planter")
	check(planters.size() == 4, "four hydroponic planters")
	var pl: Fixture = planters[0]
	var g := pl.get_component("Grower") as Grower
	g.server_tick(0.0)
	check(g.crops().has(g.crop), "planter grows something the menu needs (%s)" % g.crop)
	check(not g.crops().has(&"patty"), "patties don't grow on plants")
	var first := g.crop
	use(pl)
	check(g.crop != first, "USE switches the crop (%s)" % g.crop)
	var grow_t := Content.item(g.crop).grow_seconds
	await wait(grow_t + 1.0)
	check(g.stock >= 1, "a %s grew (%d ready)" % [g.crop, g.stock])
	grab(pl)
	check(p.held() != null and p.held().def_id == g.crop, "harvested it")
	w.despawn(p.take_held())
	# The food printer
	var pr: Fixture = w.grid.fixtures_of(&"food_printer")[0]
	var fp := pr.get_component("FoodPrinter") as FoodPrinter
	fp.server_tick(0.0)
	check(Content.item(fp.selected).grow_seconds <= 0.0, "printer starts on something planters can't grow (%s)" % fp.selected)
	fp.stock = 0
	fp.progress = 0.0
	var money := w.economy.money
	await wait(FoodPrinter.PRINT_TIME + 0.5)
	check(fp.stock >= 1, "printed one")
	check(w.economy.money < money, "printing costs credits (%s)" % GameConst.money(money - w.economy.money))
	var sel := fp.selected
	grab(pr)
	check(p.held() != null and p.held().def_id == sel, "took the printed %s" % sel)
	w.despawn(p.take_held())
	use(pr)
	check(fp.selected != sel, "USE picks something else to print (%s)" % fp.selected)
	w.economy.money = 0.0
	await wait(FoodPrinter.PRINT_TIME + 0.5)
	check(fp.status_text().contains("out of credits"), "stops when out of credits")
	w.economy.money = 250.0
	# Alien guests
	var aliens := 0
	for i in 6:
		var grp := w.customers.spawn_group(Content.archetype(&"regular_folks"), true)
		for m in grp.members if grp else []:
			if m.appearance.get("hat", &"") == &"antennae" or not Pal.SKIN_TONES.has(m.appearance.get("skin")):
				aliens += 1
	check(aliens > 0, "some guests are from other planets (%d)" % aliens)
	check(w.grid.fixtures_of(&"market_stall").is_empty(), "no market stalls in orbit")
