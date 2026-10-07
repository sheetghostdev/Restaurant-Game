class_name DayManager
extends Node
## The daily loop runs on its own; the restaurant doesn't wait for anyone:
##   MORNING (prep against the clock: deliveries, chopping, arranging; the
##            doors open automatically when prep time runs out)
##   → SERVICE (timed; customers arrive in predictable waves)
##   → CLOSING (doors shut, finish the last tables; the day ends by itself
##              once the last guests are gone)
##   → RESULTS (the day's ledger)
##   → EVENING (calm planning: buy equipment, expand, set tomorrow's order)
##   → next MORNING
## Phase changes drive music, lighting, ambience and UI.

var world: GameWorld
var day := 1
var phase := GameConst.Phase.MORNING
var hour := 8.0
var elapsed := 0.0            ## seconds since opening
var stats := {}
var last_results := {}
var _sync_t := 0.0
var _was_rush := false
var prep_total := 120.0       ## seconds of morning prep before the doors open
var prep_left := 120.0
var auto_open := true         ## false: tests and debug hold the morning
var _close_t := 0.0           ## seconds the dining room has been empty while closing
var _closing_t := 0.0         ## seconds since closing time
var _warned := {}
var streak := 0               ## happy groups in a row; raises tips until someone walks out
var goals: Array = []         ## today's goals: {id, text, target, reward, done}

## Last orders: guests still here this long after closing are shown out.
const CLOSING_LIMIT := 150.0


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld


func setup_new() -> void:
	day = 1
	_begin_morning(true)


func save_data() -> Dictionary:
	return {"day": day}


func load_data(d: Dictionary) -> void:
	day = d.get("day", 1)
	_begin_morning(false, true)


func _reset_stats() -> void:
	stats = {
		"revenue": 0.0, "expenses": 0.0, "people_served": 0, "groups_served": 0,
		"groups_lost": 0, "balked": 0, "orders_missed": 0, "refused": 0,
		"sat_sum": 0.0, "sat_n": 0, "waste": 0, "waste_cost": 0.0,
		"ingredients_used": {}, "prepped": 0, "dishes_washed": 0, "repairs": 0, "fires": 0,
		"rep_start": world.economy.reputation if world.economy else 0.0,
		"rep_walkouts": 0.0, "lost_sales": 0.0, "best_streak": 0,
		"groups_planned": world.customers.schedule.size() if world.customers else 0,
	}


# -----------------------------------------------------------------------------
# Phase transitions (authority)
# -----------------------------------------------------------------------------

## `from_load`: resuming a saved morning — the delivery was already ordered
## (and paid for) before the save, and is restored by the DeliveryManager.
func _begin_morning(first_day: bool, from_load := false) -> void:
	phase = GameConst.Phase.MORNING
	hour = morning_hour()
	elapsed = 0.0
	# A bit longer on day one, while everyone finds their way around.
	prep_total = Difficulty.factor("prep_seconds") + (30.0 if day == 1 else 0.0)
	prep_left = prep_total
	_warned.clear()
	_reset_stats()
	world.disasters.plan_day(day)
	world.customers.plan_day(day, world.economy.reputation)
	stats["groups_planned"] = world.customers.schedule.size()
	if not from_load:
		world.deliveries.morning_delivery(first_day)
	world.staff.on_new_day()
	_pick_goals()
	world.replicator.publish(&"forecast", {"f": world.disasters.forecast.duplicate(), "g": world.customers.schedule.size(), "rh": world.customers.rush_hours(), "goals": goals.map(func(g): return "%s (+%s)" % [g["text"], GameConst.money(g["reward"])])})
	_phase_changed()
	if from_load:
		Events.notify("Welcome back — Day %d" % day, &"info")
		return
	if day > 1 or not first_day:
		Events.notify("Day %d — the delivery truck is here" % day, &"info")
	Saves.autosave(world)


func open_restaurant() -> void:
	if phase != GameConst.Phase.MORNING:
		return
	world.build.drop_all_carried()
	phase = GameConst.Phase.SERVICE
	hour = float(world.format.open_hour)
	elapsed = 0.0
	Audio.play_ui(&"open_sign")
	world.lighting.flash_open()
	Events.notify("We're OPEN!", &"big", Pal.UI_GOOD)
	_phase_changed()


func _begin_closing() -> void:
	phase = GameConst.Phase.CLOSING
	_close_t = 0.0
	_closing_t = 0.0
	world.customers.on_closing()
	world.deliveries.on_closing()
	Audio.play_ui(&"day_end")
	Events.notify("Closing time — finish the last tables", &"big", Pal.UI_WARN)
	_phase_changed()


func can_finish_day() -> bool:
	return phase == GameConst.Phase.CLOSING and world.customers.active_groups() == 0


func finish_day() -> void:
	if phase != GameConst.Phase.CLOSING:
		return
	world.build.drop_all_carried()
	_discard_leftovers()
	world.staff.pay_wages()
	_check_goals(true)
	var r := build_results()
	last_results = r
	phase = GameConst.Phase.RESULTS
	world.replicator.publish(&"results", r)
	Events.day_results.emit(r)
	_phase_changed()


func continue_from_results() -> void:
	if phase != GameConst.Phase.RESULTS:
		return
	phase = GameConst.Phase.EVENING
	hour = evening_hour()
	Events.notify("Evening — plan tomorrow: expand, buy, rearrange", &"info")
	_phase_changed()


func start_next_day() -> void:
	if phase != GameConst.Phase.EVENING:
		return
	world.build.drop_all_carried()
	_discard_leftovers()   # nothing prepped in the evening keeps overnight either
	day += 1
	_begin_morning(false)


func _discard_leftovers() -> void:
	# Prepared food doesn't keep overnight; whole ingredients in crates do.
	for it in world.items_in_world():
		if it is FoodItem:
			var f := it as FoodItem
			var prepared := f.cook > 0.0 or f.def.has_tag("prepared") or f.spoiled
			if prepared:
				stats_add(&"waste", 1, f.def_id)
				stats_add(&"waste_cost", f.def.unit_cost)
				world.despawn(f)
		elif it is DishItem:
			var d := it as DishItem
			if not d.contents.is_empty():
				for c in d.contents:
					stats_add(&"waste", 1, c["id"])
				d.make_dirty()


func build_results() -> Dictionary:
	var sat: float = stats["sat_sum"] / maxf(stats["sat_n"], 1)
	var used := []
	var ing: Dictionary = stats["ingredients_used"]
	for k in ing:
		if ing[k] > 0:
			used.push_back({"id": String(k), "name": Content.display_name(k), "n": ing[k]})
	used.sort_custom(func(a, b): return a["n"] > b["n"])
	return {
		"day": day,
		"revenue": snappedf(stats["revenue"], 0.01),
		"expenses": snappedf(stats["expenses"], 0.01),
		"profit": snappedf(stats["revenue"] - stats["expenses"], 0.01),
		"people_served": stats["people_served"],
		"groups_served": stats["groups_served"],
		"groups_lost": stats["groups_lost"],
		"balked": stats["balked"],
		"orders_missed": stats["orders_missed"],
		"refused": stats["refused"],
		"satisfaction": snappedf(sat, 0.01),
		"waste": stats["waste"],
		"waste_cost": snappedf(stats["waste_cost"], 0.01),
		"ingredients": used,
		"dishes_washed": stats["dishes_washed"],
		"repairs": stats["repairs"],
		"fires": stats["fires"],
		"reputation": snappedf(world.economy.reputation, 0.01),
		"reputation_delta": snappedf(world.economy.reputation - stats["rep_start"], 0.01),
		"money": snappedf(world.economy.money, 0.01),
		"rep_walkouts": snappedf(stats.get("rep_walkouts", 0.0), 0.01),
		"lost_sales": snappedf(stats.get("lost_sales", 0.0), 0.01),
		"best_streak": stats.get("best_streak", 0),
		"groups_planned": stats.get("groups_planned", 0),
		"groups_tomorrow": world.customers.expected_groups(day + 1, world.economy.reputation),
		"goals": goals.map(func(g): return {"text": g["text"], "reward": g["reward"], "done": g["done"]}),
	}


# -----------------------------------------------------------------------------
# Stats
# -----------------------------------------------------------------------------

func stats_add(key: StringName, amount: float, sub: StringName = &"") -> void:
	if stats.is_empty():
		return
	var k := String(key)
	if k == "ingredients_used":
		var d: Dictionary = stats["ingredients_used"]
		d[sub] = d.get(sub, 0) + amount
		return
	stats[k] = stats.get(k, 0) + amount


# -----------------------------------------------------------------------------
# Daily goals: two small targets each morning, paid when the day ends
# -----------------------------------------------------------------------------

func _pick_goals() -> void:
	goals.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([day, String(world.format.id)])
	var people := 0
	for e in world.customers.schedule:
		people += 2
	var serve_n := maxi(4, int(round(people * 0.55)))
	var pool := [
		{"id": "serve", "text": "Serve %d guests" % serve_n, "target": serve_n, "reward": 50.0},
		{"id": "no_walkouts", "text": "Nobody walks out", "target": 0, "reward": 60.0},
		{"id": "perfect", "text": "Serve %d perfect dishes" % maxi(3, serve_n / 2), "target": maxi(3, serve_n / 2), "reward": 45.0},
		{"id": "streak", "text": "A streak of 5 happy tables", "target": 5, "reward": 55.0},
		{"id": "no_waste", "text": "Waste at most 3 ingredients", "target": 3, "reward": 40.0},
	]
	if day <= 1:
		pool = pool.slice(0, 3)   # simple ones on the first day
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for k in 2:
		var g: Dictionary = pool[k].duplicate()
		g["done"] = false
		goals.push_back(g)


## Marks goals reached so far (`final`: the day is over, so "nobody walked
## out" and "little waste" can be judged, and rewards are paid).
func _check_goals(final := false) -> void:
	for g in goals:
		if g["done"]:
			continue
		var ok := false
		match String(g["id"]):
			"serve": ok = int(stats.get("people_served", 0)) >= int(g["target"])
			"perfect": ok = int(stats.get("perfect", 0)) >= int(g["target"])
			"streak": ok = int(stats.get("best_streak", 0)) >= int(g["target"])
			"no_walkouts": ok = final and int(stats.get("groups_lost", 0)) == 0 and int(stats.get("people_served", 0)) > 0
			"no_waste": ok = final and int(stats.get("waste", 0)) <= int(g["target"]) and int(stats.get("people_served", 0)) > 0
		if ok:
			g["done"] = true
			if not final:
				Events.notify("Goal done: %s! (+%s tonight)" % [g["text"], GameConst.money(g["reward"])], &"big", Pal.UI_GOOD)
				Audio.play_ui(&"level_up")
	if final:
		for g in goals:
			if g["done"]:
				world.economy.earn(float(g["reward"]), "Goal: %s" % g["text"])


## Tips go up with every happy table in a row (up to +50%).
func tip_bonus() -> float:
	return 0.1 * mini(streak, 5)


func record_group(g: CustomerGroup, satisfaction: float, upset: bool) -> void:
	var weight := g.archetype.reputation_weight
	if upset:
		# Walking out costs: reputation (fewer guests tomorrow), the sale, and
		# the streak. Say so, loudly, so it's clear what went wrong.
		stats["groups_lost"] += 1
		var loss := 0.12 * weight * Difficulty.factor("rep_loss")
		world.economy.change_reputation(-loss)
		stats["rep_walkouts"] = stats.get("rep_walkouts", 0.0) + loss
		var lost := g.unserved_value()
		stats["lost_sales"] = stats.get("lost_sales", 0.0) + lost
		var who := g.label()
		var msg := "%s walked out!  −%.2f★" % [who, loss]
		if lost >= 1.0:
			msg += "  (lost %s)" % GameConst.money(lost)
		if streak >= 2:
			msg += "  · streak lost"
		Events.notify(msg, &"error")
		streak = 0
		_publish()
		Events.customer_left.emit(false, g.members[0].global_position if not g.members.is_empty() else Vector3.ZERO)
		return
	if satisfaction >= 0.6:
		streak += 1
		stats["best_streak"] = maxi(int(stats.get("best_streak", 0)), streak)
		if streak in [3, 5, 8, 12, 20]:
			Events.notify("Hot streak ×%d — tips +%d%%" % [streak, roundi(tip_bonus() * 100.0)], &"big", Pal.UI_GOOD)
		_publish()
	stats["groups_served"] += 1
	stats["people_served"] += g.members.size()
	_check_goals()
	stats["sat_sum"] += satisfaction * g.members.size()
	stats["sat_n"] += g.members.size()
	var rep := (satisfaction - 0.62) * 0.09 * weight
	if rep < 0.0:
		rep *= Difficulty.factor("rep_loss")
	world.economy.change_reputation(rep)
	Events.customer_left.emit(true, g.members[0].global_position if not g.members.is_empty() else Vector3.ZERO)


func record_balk(people: int) -> void:
	stats["balked"] = stats.get("balked", 0) + people
	world.economy.change_reputation(-0.01 * people)


# -----------------------------------------------------------------------------
# Tick
# -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null or not Net.is_authority():
		return
	match phase:
		GameConst.Phase.MORNING:
			if auto_open:
				prep_left = maxf(prep_left - delta, 0.0)
			hour = morning_hour() + 3.0 * (1.0 - prep_left / maxf(prep_total, 1.0))
			for w in [30, 10]:
				if prep_left <= w and not _warned.has(w) and prep_total > w + 5:
					_warned[w] = true
					Events.notify("Doors open in %d seconds!" % w, &"big" if w == 10 else &"warning", Pal.UI_WARN)
					Audio.play_ui(&"timer_ring")
			if prep_left <= 14.0 and not _warned.has("guests"):
				_warned["guests"] = true
				world.customers.early_arrival()
			if prep_left <= 0.0:
				open_restaurant()
		GameConst.Phase.SERVICE:
			elapsed += delta
			var span := float(world.format.close_hour - world.format.open_hour)
			hour = world.format.open_hour + span * elapsed / world.format.service_seconds
			if hour >= world.format.close_hour:
				hour = world.format.close_hour
				_begin_closing()
			var rush := world.customers.is_rush_hour(hour)
			if rush != _was_rush:
				_was_rush = rush
				if rush:
					Events.notify("RUSH HOUR!", &"big", Pal.UI_BAD)
					Audio.play_ui(&"timer_ring")
				_phase_changed()
		GameConst.Phase.CLOSING:
			hour = minf(hour + delta / 30.0, world.format.close_hour + 2.0)
			_closing_t += delta
			if _closing_t > CLOSING_LIMIT and world.customers.active_groups() > 0:
				Events.notify("Last orders long gone: the remaining guests head home", &"info")
				world.customers.send_everyone_home()
			if can_finish_day():
				_close_t += delta
				if _close_t >= 3.0:
					finish_day()
			else:
				_close_t = 0.0
		GameConst.Phase.EVENING:
			hour = minf(hour + delta / 90.0, evening_hour() + 2.0)
	world.lighting.set_hour(hour)
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.5
		_publish()


## The clock follows the restaurant's hours: a coffee shop's prep starts
## before dawn, a bar's evening planning happens after midnight.
func morning_hour() -> float:
	return world.format.open_hour - 3.0


func evening_hour() -> float:
	return maxf(world.format.close_hour + 0.5, 21.5)


func is_rush() -> bool:
	return phase == GameConst.Phase.SERVICE and _was_rush


func _phase_changed() -> void:
	world.lighting.set_hour(hour)
	_publish()
	Events.phase_changed.emit(phase)
	_update_music()


func _update_music() -> void:
	match phase:
		GameConst.Phase.MORNING:
			Audio.set_music_state(&"prep")
		GameConst.Phase.SERVICE:
			Audio.set_music_state(&"rush" if _was_rush else &"service")
		GameConst.Phase.CLOSING, GameConst.Phase.RESULTS, GameConst.Phase.EVENING:
			Audio.set_music_state(&"closing")


func _publish() -> void:
	if world.replicator:
		world.replicator.publish(&"day", {"d": day, "p": phase, "h": snappedf(hour, 0.01), "e": snappedf(elapsed, 0.1), "r": _was_rush, "pl": snappedf(prep_left, 0.1), "sk": streak})


func apply_shared(d: Dictionary) -> void:
	var old_phase := phase
	var old_rush := _was_rush
	day = d.get("d", day)
	phase = d.get("p", phase)
	hour = d.get("h", hour)
	elapsed = d.get("e", elapsed)
	_was_rush = d.get("r", false)
	prep_left = d.get("pl", prep_left)
	streak = d.get("sk", streak)
	world.lighting.set_hour(hour)
	if old_phase != phase or old_rush != _was_rush:
		Events.phase_changed.emit(phase)
		_update_music()
	Events.clock_changed.emit(hour)


func phase_name() -> String:
	return GameConst.PHASE_NAMES[phase]
