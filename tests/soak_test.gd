extends Node
## Soak test: plays two full days at high speed with real scheduled customers.
## A helper "bot" takes orders and serves ~75% of dishes (spawning finished
## plates), clears tables and washes up, so every phase and most customer
## outcomes (served, upset, balked, closing) get exercised. Any script error in
## the log means failure — run it through a log grep (see README).
## Run: godot --headless --path . res://tests/soak_test.tscn

var main: Node
var w: GameWorld
var served := 0
var skipped := 0


func _ready() -> void:
	Saves.active_slot = "soak_test"
	Saves.delete()
	Engine.time_scale = 6.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.start_offline(false, main.setup_from_args())
	await get_tree().create_timer(0.5).timeout
	w = GameWorld.current
	w.economy.earn(2000.0, "soak")
	w.staff.hire(&"dish_hand")
	for day in 2:
		await _play_day()
	print("SOAK: day=%d money=%.0f rep=%.2f served=%d skipped=%d entities=%d" % [w.day.day, w.economy.money, w.economy.reputation, served, skipped, w.entities.size()])
	print("SOAK DONE")
	Saves.delete()
	Engine.time_scale = 1.0
	get_tree().quit()


func _play_day() -> void:
	await get_tree().create_timer(3.0).timeout
	w.day.open_restaurant()
	var p: PlayerCharacter = w.players()[0]
	p.input_override = true
	while w.day.phase == GameConst.Phase.SERVICE or w.day.phase == GameConst.Phase.CLOSING:
		await get_tree().create_timer(1.0).timeout
		_bot_step(p)
		if w.day.phase == GameConst.Phase.CLOSING and w.day.can_finish_day():
			w.day.finish_day()
	print("SOAK: day %d results %s" % [w.day.day, JSON.stringify(w.day.last_results).substr(0, 240)])
	w.day.continue_from_results()
	await get_tree().create_timer(1.0).timeout
	w.day.start_next_day()


func _bot_step(p: PlayerCharacter) -> void:
	for g in w.customers.groups.duplicate():
		if g.state == CustomerGroup.State.READY and randf() < 0.8:
			g.take_order(p)
		if g.state in [CustomerGroup.State.WAITING_FOOD, CustomerGroup.State.EATING]:
			for m in g.members:
				for o in m.orders:
					if o.get("served", false) or o.get("bot_skip", false):
						continue
					if randf() < 0.25:
						o["bot_skip"] = true
						skipped += 1
						continue
					var r := Content.recipe(o["recipe"])
					var contents := []
					for id in r.required + o.get("extras", []):
						var d := Content.item(id)
						var ck := 0.0
						if d.cook_profile:
							ck = (d.cook_profile.stage_ends[d.cook_profile.perfect_stage - 1] + d.cook_profile.stage_ends[d.cook_profile.perfect_stage]) * 0.5
						contents.push_back({"id": String(id), "ck": ck})
					var dish: DishItem = w.spawn_item(&"dishware", {"p": 0 if r.container == "mug" else 1, "m": 1 if r.container == "mug" else 0, "c": contents})
					if p.held():
						w.despawn(p.take_held())
					p.hold(dish)
					if g.serve(p, dish, m.seat_table):
						served += 1
					elif p.held():
						w.despawn(p.take_held())
	# Clear dirty tables into the sink so the dish hand has work.
	for f in w.grid.all_fixtures():
		var st := f.get_component("SeatingTable") as SeatingTable
		if st and st.has_dirty_dishes() and randf() < 0.5:
			if p.held():
				w.despawn(p.take_held())
			p.global_position = f.global_position + Vector3(0, 0, 0.8)
			if st.query(p, GameConst.Verb.GRAB).size() > 0:
				st.perform(p, GameConst.Verb.GRAB, 0.0)
			var sink: Fixture = w.grid.fixtures_of(&"sink")[0]
			if p.held():
				var s := sink.get_component("Sink") as Sink
				if not s.auto_insert(p.held()):
					w.despawn(p.take_held())
		if st and st.messy and st.group() == null:
			st.messy = false
			f.mark_dirty()
