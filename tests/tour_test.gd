extends Node
## Headless test of the Franchise Tour: winning a leg franchises you to the
## next place (money and stars carried, plus an opening budget), the tour
## survives save/load, missing the goal ends it, and One Strike ends it at
## the first walkout.
## Run: godot --headless --path . res://tests/tour_test.tscn

var failures := 0
var checks := 0
var main: Node
var w: GameWorld
var _log: Array[String] = []


func _ready() -> void:
	Saves.active_slot = "tour_test"
	Saves.delete()
	Engine.time_scale = 4.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await t_franchise()
	await t_missed()
	await t_one_strike()
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


## Plays the current day straight to its results.
func finish_day() -> Dictionary:
	w.day.auto_open = false
	w.debug_command("start_service", [])
	await wait(0.2)
	w.debug_command("end_service", [])
	await wait(0.4)
	w.debug_command("end_service", [])
	await wait(0.4)
	return w.day.last_results


func start_tour(strike: bool) -> void:
	main.start_offline(false, {"mode": "tour", "format": "coffee_shop", "strike": strike, "location": "orbital"})
	await wait(0.6)
	w = GameWorld.current


func t_franchise() -> void:
	print("[franchise]")
	await start_tour(false)
	check(not w.tour.is_empty() and Tour.leg(w.tour) == 0, "a tour starts at leg 1")
	check(w.location.id == &"main_street", "on Main Street, whatever place was picked")
	check(w.format.id == &"coffee_shop", "with the chosen kind of restaurant")
	var r := await finish_day()
	check(r.has("tour") and String(r["tour"]["verdict"]) == "", "day 1 of %d: no verdict yet" % Tour.DAYS)
	# Jump to the last day of the leg with the stars to spare.
	w.day.phase = GameConst.Phase.EVENING
	w.day.start_next_day()
	w.day.day = Tour.DAYS
	w.economy.reputation = Tour.TARGETS[0] + 0.2
	r = await finish_day()
	check(String(r["tour"]["verdict"]) == "franchised", "goal reached on the last day: franchised (%s)" % r["tour"]["verdict"])
	var money := w.economy.money
	var rep := w.economy.reputation
	Net.request("tour_next")
	await wait(0.8)
	w = GameWorld.current
	check(w.location.id == &"express" and Tour.leg(w.tour) == 1, "now running the Dining Car Express (leg 2)")
	check(w.day.day == 1 and w.day.phase == GameConst.Phase.MORNING, "a fresh day 1 at the new place")
	check(absf(w.economy.money - (money + Tour.FRANCHISE_BONUS)) < 1.0, "money carried over, plus an opening budget (%.0f → %.0f)" % [money, w.economy.money])
	check(absf(w.economy.reputation - rep) < 0.01, "and the stars came too")
	check(w.format.id == &"coffee_shop" and w.players().size() == 1, "same restaurant type, same crew")
	check(Saves.save_game(w), "saved mid-tour")
	main.start_offline(true)
	await wait(0.6)
	w = GameWorld.current
	check(Tour.leg(w.tour) == 1 and w.location.id == &"express", "the tour survives save and load")
	check(int(Saves.meta().get("tour", {}).get("leg", -1)) == 1, "the title screen can see it's a tour")


func t_missed() -> void:
	print("[missed]")
	w.day.day = Tour.DAYS
	w.economy.reputation = Tour.TARGETS[1] - 0.3
	var r := await finish_day()
	check(String(r["tour"]["verdict"]) == "missed", "short of the goal on the last day: the tour ends")
	check(int(r["tour"]["score"]) > 0, "with a score (%d)" % int(r["tour"]["score"]))
	Net.request("tour_end")
	await wait(0.5)
	check(GameWorld.current == null or not is_instance_valid(GameWorld.current) or GameWorld.current.is_queued_for_deletion(), "back to the title")
	check(not Saves.has_save(), "the finished run's save is gone")


func t_one_strike() -> void:
	print("[one strike]")
	await start_tour(true)
	check(w.tour.get("strike", false), "One Strike is on")
	w.day.auto_open = false
	w.debug_command("start_service", [])
	await wait(0.3)
	var g := w.customers.spawn_group(Content.archetype(&"traveler"), true)
	w.day.record_group(g, 0.0, true)
	await wait(0.5)
	var r := w.day.last_results
	check(w.day.phase == GameConst.Phase.RESULTS and String(r.get("tour", {}).get("verdict", "")) == "struck", "the first walkout ends the tour that night")
