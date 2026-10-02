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
	await _run_scenario()
	await get_tree().create_timer(delay).timeout
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
		"evening":
			w.debug_command("start_service", [])
			w.debug_command("end_service", [])
			await get_tree().create_timer(0.3).timeout
			w.debug_command("end_service", [])
			await get_tree().create_timer(0.5).timeout
			w.debug_command("end_service", [])
		"fire":
			w.debug_command("start_service", [])
			w.disasters.trigger(&"grease_fire")
			w.disasters.trigger(&"pipe_leak")
			w.disasters.trigger(&"dishwasher_breakdown")


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
