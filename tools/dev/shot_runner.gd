extends Node
## Dev tool: boots the game, optionally runs a scripted scenario, and saves
## screenshots. Used for visual checks in CI-like environments.
## Run: godot --path . res://tools/dev/shot_runner.tscn -- --shot=out.png [--delay=3] [--scenario=name]

var shot_path := "user://shot.png"
var delay := 3.0
var scenario := ""
var main: Node


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--delay="):
			delay = float(a.substr(8))
		elif a.begins_with("--scenario="):
			scenario = a.substr(11)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	if not "--menu" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		main.start_offline(false)
	await get_tree().create_timer(0.5).timeout
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--players=") and _world():
			var n := int(a.substr(10))
			for i in range(1, n):
				var pl := _world().add_local_player(Inputs.PAD_BASE + i)
				pl.global_position = Vector3(10.5 + i * 1.2, 0, 5.0)
	await _run_scenario()
	if "--closeup" in OS.get_cmdline_user_args() and _world():
		_world().camera.zoom_bias = -0.55
		_world().camera.player_focus = 0.9
	await get_tree().create_timer(delay).timeout
	_report_bad_transforms(get_tree().root)
	await _shot(shot_path)
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)


func _world() -> GameWorld:
	return GameWorld.current


func _run_scenario() -> void:
	var w := _world()
	if w == null:
		return
	match scenario:
		"service":
			w.debug_command("start_service", [])
			for a in ["family", "work_crew", "regular_folks", "regular_folks"]:
				w.customers.spawn_group(Content.archetype(StringName(a)), true)
			await get_tree().create_timer(9.0).timeout
		"kitchen":
			_stage_kitchen(w)
		"target":
			_stage_kitchen(w)
			var pl: PlayerCharacter = w.players()[0]
			pl.input_override = true
			pl.global_position = Vector3(11.5, 0, 4.55)
			pl.rotation.y = PI
			pl.facing = Vector3(0, 0, -1)
		"dining":
			Engine.time_scale = 3.0
			w.debug_command("start_service", [])
			var groups := []
			for a in ["family", "work_crew", "business", "regular_folks"]:
				groups.push_back(w.customers.spawn_group(Content.archetype(StringName(a)), true))
			var t := 0.0
			while t < 40.0:
				await get_tree().create_timer(0.5).timeout
				t += 0.5
				var ready := 0
				for g in groups:
					if g and g.state == CustomerGroup.State.READY:
						g.take_order(w.players()[0])
					if g and g.state >= CustomerGroup.State.WAITING_FOOD:
						ready += 1
				if ready == groups.size():
					break
			# Serve half the orders so some guests eat while others wait.
			var k := 0
			for g in groups:
				if g == null:
					continue
				for m in g.members:
					k += 1
					if k % 2 == 0:
						continue
					for o in m.orders:
						var r := Content.recipe(o["recipe"])
						var contents := []
						for id in r.required:
							var d := Content.item(id)
							var ck := 0.0
							if d.cook_profile:
								ck = (d.cook_profile.stage_ends[d.cook_profile.perfect_stage - 1] + d.cook_profile.stage_ends[d.cook_profile.perfect_stage]) * 0.5
							contents.push_back({"id": String(id), "ck": ck})
						var dish: DishItem = w.spawn_item(&"dishware", {"p": 0 if r.container == "mug" else 1, "m": 1 if r.container == "mug" else 0, "c": contents})
						var pl: PlayerCharacter = w.players()[0]
						pl.hold(dish)
						if not g.serve(pl, dish, m.seat_table):
							w.despawn(pl.take_held())
			Engine.time_scale = 1.0
			w.players()[0].global_position = Vector3(4.5, 0, 4.5)
		"results", "evening":
			w.debug_command("start_service", [])
			w.debug_command("end_service", [])
			await get_tree().create_timer(0.3).timeout
			w.debug_command("end_service", [])
			await get_tree().create_timer(0.5).timeout
			if scenario == "evening":
				w.debug_command("end_service", [])
				await get_tree().create_timer(4.0).timeout
		"fire":
			w.debug_command("start_service", [])
			(w.grid.fixtures_of(&"grill")[0].get_component("Flammable") as Flammable).ignite()
			w.disasters.trigger(&"pipe_leak")
			w.disasters.trigger(&"dishwasher_breakdown")
			var p: PlayerCharacter = w.players()[0]
			var ext: Fixture = w.grid.fixtures_of(&"extinguisher_station")[0]
			p.hold(ext.primary_slot().take())
			p.global_position = Vector3(12.4, 0, 2.2)
			p.rotation.y = PI
			p.facing = Vector3(0, 0, -1)
		"catalog":
			var p2: PlayerCharacter = w.players()[0]
			w.hud.catalog.open_for(p2)
			await get_tree().create_timer(1.5).timeout


func _stage_kitchen(w: GameWorld) -> void:
	# Put food on stations so the screenshot shows cooking states.
	var grills := w.grid.fixtures_of(&"grill")
	if grills.size() > 0:
		var p := w.spawn_item(&"patty", {"ck": 0.7}, {"slot": [grills[0].net_id, 0]})
	if grills.size() > 1:
		w.spawn_item(&"patty", {"ck": 0.2}, {"slot": [grills[1].net_id, 0]})
	for f in w.grid.fixtures_of(&"fryer"):
		w.spawn_item(&"fries", {"ck": 0.8}, {"slot": [f.net_id, 0]})
	var boards := w.grid.fixtures_of(&"cutting_board")
	if boards.size() > 0:
		w.spawn_item(&"tomato", {"ch": 0.8}, {"slot": [boards[0].net_id, 0]})
	if boards.size() > 1:
		w.spawn_item(&"lettuce", {}, {"slot": [boards[1].net_id, 0]})
	var counters := w.grid.fixtures_of(&"counter")
	var dish := w.spawn_item(&"dishware", {"p": 1, "m": 0, "c": [{"id": "bun", "ck": 0.0}, {"id": "patty", "ck": 0.75}, {"id": "lettuce_chopped", "ck": 0.0}, {"id": "tomato_sliced", "ck": 0.0}]}, {"slot": [counters[1].net_id, 0]})
	var d2 := w.spawn_item(&"dishware", {"p": 1, "m": 0, "c": [{"id": "fries", "ck": 0.8}]}, {"slot": [counters[2].net_id, 0]})
	var d3 := w.spawn_item(&"dishware", {"p": 1, "m": 0, "c": [{"id": "lettuce_chopped", "ck": 0.0}, {"id": "tomato_sliced", "ck": 0.0}]}, {"slot": [counters[0].net_id, 0]})
	var cm := w.grid.fixtures_of(&"coffee_machine")
	if cm.size() > 0:
		w.spawn_item(&"dishware", {"p": 0, "m": 1}, {"slot": [cm[0].net_id, 0]})


func _report_bad_transforms(n: Node) -> void:
	if n is Node3D and n.is_inside_tree():
		var t := (n as Node3D).transform
		if not (t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite() and t.basis.z.is_finite()):
			print("BAD TRANSFORM: ", n.get_path(), " ", t)
			return
	for c in n.get_children():
		_report_bad_transforms(c)
