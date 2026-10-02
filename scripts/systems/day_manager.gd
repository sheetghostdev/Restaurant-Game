class_name DayManager
extends Node
## The daily loop:
##   MORNING (calm prep: deliveries, chopping, arranging; untimed)
##   → SERVICE (timed; customers arrive in predictable waves)
##   → CLOSING (doors shut, finish the last tables, clean up)
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
	}


# -----------------------------------------------------------------------------
# Phase transitions (authority)
# -----------------------------------------------------------------------------

## `from_load`: resuming a saved morning — the delivery was already ordered
## (and paid for) before the save, and is restored by the DeliveryManager.
func _begin_morning(first_day: bool, from_load := false) -> void:
	phase = GameConst.Phase.MORNING
	hour = 8.0
	elapsed = 0.0
	_reset_stats()
	world.disasters.plan_day(day)
	world.customers.plan_day(day, world.economy.reputation)
	if not from_load:
		world.deliveries.morning_delivery(first_day)
	world.staff.on_new_day()
	world.replicator.publish(&"forecast", {"f": world.disasters.forecast.duplicate(), "g": world.customers.schedule.size(), "rh": world.customers.rush_hours()})
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
	hour = 21.5
	Events.notify("Evening — plan tomorrow: expand, buy, rearrange", &"info")
	_phase_changed()


func start_next_day() -> void:
	if phase != GameConst.Phase.EVENING:
		return
	world.build.drop_all_carried()
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


func record_group(g: CustomerGroup, satisfaction: float, upset: bool) -> void:
	var weight := g.archetype.reputation_weight
	if upset:
		stats["groups_lost"] += 1
		world.economy.change_reputation(-0.07 * weight * Difficulty.factor("rep_loss"))
		Events.customer_left.emit(false, g.members[0].global_position if not g.members.is_empty() else Vector3.ZERO)
		return
	stats["groups_served"] += 1
	stats["people_served"] += g.members.size()
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
			hour = minf(hour + delta / 60.0, 10.75)
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
			hour = minf(hour + delta / 30.0, 23.0)
		GameConst.Phase.EVENING:
			hour = minf(hour + delta / 90.0, 23.5)
	world.lighting.set_hour(hour)
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.5
		_publish()


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
		world.replicator.publish(&"day", {"d": day, "p": phase, "h": snappedf(hour, 0.01), "e": snappedf(elapsed, 0.1), "r": _was_rush})


func apply_shared(d: Dictionary) -> void:
	var old_phase := phase
	var old_rush := _was_rush
	day = d.get("d", day)
	phase = d.get("p", phase)
	hour = d.get("h", hour)
	elapsed = d.get("e", elapsed)
	_was_rush = d.get("r", false)
	world.lighting.set_hour(hour)
	if old_phase != phase or old_rush != _was_rush:
		Events.phase_changed.emit(phase)
		_update_music()
	Events.clock_changed.emit(hour)


func phase_name() -> String:
	return GameConst.PHASE_NAMES[phase]
