class_name EventManager
extends Node
## Operational disasters and special days. Events are rolled each morning so
## they stay occasional, and crowd events are announced during prep so players
## can plan. Also owns floor mess and the hand tools that deal with chaos.

var world: GameWorld
var today: Array = []           ## [{id, hour, done}]
var forecast: Array[String] = []
var active_fires := 0
var power_out := false
var _power_t := 0.0
var _spray_t := 0.0
var _inspection_t := -1.0
var _alarm_node: Node3D


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld


func plan_day(day: int) -> void:
	today.clear()
	forecast.clear()
	world.customers.demand_mods.clear()
	var fmt := world.format
	for e in Content.sorted_values(Content.events):
		var ev := e as EventDef
		if ev.min_day > day:
			continue
		if randf() >= ev.chance_per_day:
			continue
		if ev.kind == "crowd":
			var hours: Array = ev.params.get("hours", [])
			var mult: float = ev.params.get("mult", 1.5)
			for h in hours:
				world.customers.demand_mods[int(h)] = world.customers.demand_mods.get(int(h), 1.0) * mult
			if ev.params.has("all_day"):
				for h in range(fmt.open_hour, fmt.close_hour):
					world.customers.demand_mods[h] = world.customers.demand_mods.get(h, 1.0) * float(ev.params["all_day"])
			forecast.push_back(ev.warning_text if ev.warning_text != "" else ev.display_name)
			continue
		var h0: float = ev.params.get("hour_min", fmt.open_hour + 1.0)
		var h1: float = ev.params.get("hour_max", fmt.close_hour - 1.5)
		today.push_back({"id": ev.id, "hour": randf_range(h0, h1), "done": false})
		if ev.kind == "delivery" or ev.kind == "inspection":
			forecast.push_back(ev.warning_text if ev.warning_text != "" else ev.display_name)


func apply_shared_forecast(d: Dictionary) -> void:
	forecast.clear()
	for s in d.get("f", []):
		forecast.push_back(s)


func _physics_process(delta: float) -> void:
	if world == null or world.day == null:
		return
	if Net.is_authority() and world.day.phase == GameConst.Phase.SERVICE:
		for ev in today:
			if not ev["done"] and world.day.hour >= ev["hour"]:
				ev["done"] = true
				trigger(ev["id"])
	if Net.is_authority() and power_out:
		_power_t -= delta
		if _power_t <= 0.0:
			set_power(true)
			Events.notify("Power's back!", &"info")
			Audio.play_ui(&"repair_done")
	if Net.is_authority() and _inspection_t >= 0.0:
		_inspection_t -= delta
		if _inspection_t < 0.0:
			_grade_inspection()
	_update_alarm()


func trigger(id: StringName) -> bool:
	match id:
		&"grease_fire":
			var cands := _fixtures_with("Flammable", func(f): return f.get_component("Cooker") != null and f.is_working())
			if cands.is_empty():
				return false
			(cands.pick_random().get_component("Flammable") as Flammable).ignite()
		&"dishwasher_breakdown":
			return _break_random(func(f): return f.get_component("Dishwasher") != null)
		&"fridge_failure":
			if _break_random(func(f): return f.def_id == &"fridge"):
				Events.notify("The fridge stopped cooling! Move the meat!", &"big", Pal.UI_BAD)
				return true
			return false
		&"machine_breakdown":
			return _break_random(func(f): return f.get_component("Cooker") != null or f.get_component("CoffeeBrewer") != null)
		&"equipment_jam":
			var conv := _fixtures_with("Conveyor", func(_f): return true)
			if conv.is_empty():
				return false
			(conv.pick_random().get_component("Conveyor") as Conveyor).jam()
			Events.notify("A conveyor jammed!", &"warning")
		&"pipe_leak":
			var sinks := _fixtures_with("Sink", func(_f): return true)
			if sinks.is_empty():
				return false
			var s: Fixture = sinks.pick_random()
			for k in 3:
				spawn_mess(&"spill", s.global_position + s.front_vec() * (0.9 + k * 0.5) + Vector3(randf_range(-0.4, 0.4), 0, 0))
			Audio.play_at(&"splash", s.global_position)
			Events.notify("A pipe burst! Mop it up before someone slips", &"big", Pal.UI_WARN)
		&"surprise_delivery":
			var items := []
			for s2 in Content.supplies.values():
				if randf() < 0.4:
					items.push_back({"supply": String(s2.id)})
			if items.is_empty():
				items.push_back({"supply": "supply_potatoes"})
			world.deliveries.schedule_extra(items, 1.0, "A surprise delivery")
			Events.notify("Your supplier sent extra stock — mid-rush!", &"warning")
		&"health_inspection":
			start_inspection()
		&"power_outage":
			set_power(false)
			_power_t = 16.0
			Events.notify("Power cut! Machines are down for a moment...", &"big", Pal.UI_WARN)
			Audio.play_ui(&"breakdown")
		_:
			return false
	return true


func set_power(on: bool) -> void:
	power_out = not on
	world.builder.power_dim = 0.0 if on else 1.0
	if Net.is_authority():
		world.replicator.publish(&"power", {"out": power_out})


func apply_shared_power(d: Dictionary) -> void:
	set_power(not d.get("out", false))


func _fixtures_with(component: String, filter: Callable) -> Array:
	var out := []
	for f in world.grid.all_fixtures():
		if f.get_component(component) and filter.call(f):
			out.push_back(f)
	return out


func _break_random(filter: Callable) -> bool:
	var cands := _fixtures_with("Breakable", func(f): return filter.call(f) and not (f.get_component("Breakable") as Breakable).broken)
	if cands.is_empty():
		return false
	(cands.pick_random().get_component("Breakable") as Breakable).break_down()
	return true


# -----------------------------------------------------------------------------
# Fires
# -----------------------------------------------------------------------------

func on_fire_started(f: Fixture) -> void:
	active_fires += 1
	world.stats_add(&"fires", 1)
	Events.notify("FIRE on the %s! Grab the extinguisher!" % f.display_name(), &"big", Pal.UI_BAD)
	world.camera.add_shake(0.6)


func on_fire_out(_f: Fixture) -> void:
	active_fires = maxi(active_fires - 1, 0)
	Events.notify("Fire's out. Phew.", &"info")


func _update_alarm() -> void:
	var burning := false
	for f in world.grid.all_fixtures():
		var fl := f.get_component("Flammable") as Flammable
		if fl and fl.burning:
			burning = true
			break
	if _alarm_node == null:
		_alarm_node = Node3D.new()
		world.effects_root.add_child(_alarm_node)
	_alarm_node.global_position = world.camera.focus_point()
	Audio.loop(_alarm_node, &"alarm_loop", burning, -8.0)


# -----------------------------------------------------------------------------
# Mess
# -----------------------------------------------------------------------------

func spawn_mess(kind: StringName, pos: Vector3) -> Mess:
	if not Net.is_authority():
		return null
	var c := GameConst.world_to_cell(pos)
	if not world.grid.is_building(c) and not world.grid.in_lot(c):
		return null
	for m in get_tree().get_nodes_in_group(&"messes"):
		if (m as Mess).def_id == kind and (m as Node3D).global_position.distance_to(pos) < 0.5:
			(m as Mess).amount = 1.0
			return m
	return world.spawn_entity(&"mess", kind, {"a": 1.0}, {"pos": [pos.x, 0.012, pos.z], "yaw": 0.0}) as Mess


func is_slippery(pos: Vector3) -> bool:
	for m in get_tree().get_nodes_in_group(&"messes"):
		var mm := m as Mess
		if mm.is_slippery() and mm.global_position.distance_squared_to(pos) < 0.2:
			return true
	return false


func mess_count() -> int:
	return get_tree().get_nodes_in_group(&"messes").size()


# -----------------------------------------------------------------------------
# Tools
# -----------------------------------------------------------------------------

func use_tool(p: PlayerCharacter, tool: ToolItem, delta: float) -> void:
	var fwd := p.facing_dir()
	if tool.def_id == &"extinguisher":
		if tool.charge <= 0.0:
			if p.use_pressed:
				Events.notify("Extinguisher is empty — put it back on its stand to refill", &"warning")
				Audio.play_at(&"error", p.global_position)
			return
		p.play_action(CharacterRig.Anim.SPRAY, 0.2)
		tool.charge = maxf(tool.charge - delta * 0.07, 0.0)
		_spray_t -= delta
		if _spray_t <= 0.0:
			_spray_t = 0.08
			world.fx.foam(p.global_position + Vector3(0, 0.8, 0) + fwd * 0.5, (fwd + Vector3(0, -0.15, 0)).normalized())
			Audio.play_at(&"extinguisher_loop", p.global_position, -10.0)
			tool.mark_dirty()
		for f in world.grid.all_fixtures():
			var fl := f.get_component("Flammable") as Flammable
			if fl == null or not fl.burning:
				continue
			var to: Vector3 = (f as Fixture).global_position - p.global_position
			to.y = 0
			if to.length() < 2.4 and fwd.dot(to.normalized()) > 0.55:
				fl.extinguish(delta * 0.85)
	elif tool.def_id == &"mop":
		p.play_action(CharacterRig.Anim.WIPE, 0.2)
		var center := p.global_position + fwd * 0.6
		var any := false
		for m in get_tree().get_nodes_in_group(&"messes"):
			var mm := m as Mess
			if mm.global_position.distance_to(center) < 0.85:
				any = true
				if mm.clean(delta):
					var at := mm.global_position
					world.despawn(mm)
					world.fx.sparkle(at + Vector3(0, 0.2, 0), Color(0.8, 0.95, 1.0))
		_spray_t -= delta
		if _spray_t <= 0.0:
			_spray_t = 0.4
			Audio.play_at(&"mop_loop", center, -8.0 if any else -14.0)


# -----------------------------------------------------------------------------
# Health inspection
# -----------------------------------------------------------------------------

func start_inspection() -> void:
	_inspection_t = 25.0
	Events.notify("A health inspector just walked in! Clean up — 25 seconds!", &"big", Pal.UI_WARN)
	Audio.play_ui(&"timer_ring")


func _grade_inspection() -> void:
	var problems := 0
	problems += mess_count()
	for f in world.grid.all_fixtures():
		var st := f.get_component("SeatingTable") as SeatingTable
		if st and (st.messy or st.has_dirty_dishes()) and world.customers.group_at_table(f) == null:
			problems += 1
		var tb := f.get_component("TrashBin") as TrashBin
		if tb and not tb.outdoor_dumpster and tb.fill >= tb.capacity:
			problems += 2
	for it in world.items_in_world():
		if (it as Item).spoiled:
			problems += 1
	if problems <= 1:
		world.economy.change_reputation(0.25)
		Events.notify("Inspection: A+! Spotless kitchen. Reputation up!", &"big", Pal.UI_GOOD)
	elif problems <= 4:
		world.economy.change_reputation(0.05)
		Events.notify("Inspection: B. A few issues (%d)." % problems, &"info")
	else:
		world.economy.change_reputation(-0.12 - problems * 0.02)
		world.economy.charge(15.0 * problems, "Health code fine")
		Events.notify("Inspection failed (%d problems). Fined!" % problems, &"big", Pal.UI_BAD)
