extends Node
## Two-process test of a Franchise Tour leg change online: the host wins
## Main Street and franchises to the train; the connected client must follow
## to the new place and get its player back.
##   godot --headless --path . res://tests/net_tour_test.tscn -- --net-host
##   godot --headless --path . res://tests/net_tour_test.tscn -- --net-client

var main: Node
var is_host := false


func _ready() -> void:
	is_host = "--net-host" in OS.get_cmdline_user_args()
	Saves.active_slot = "net_tour_host" if is_host else "net_tour_client"
	Saves.delete()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	if is_host:
		await _host()
	else:
		await _client()


func _host() -> void:
	main.start_host({"mode": "tour", "format": "diner"})
	var t := 0.0
	while Net.multiplayer.get_peers().is_empty() and t < 20.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	await get_tree().create_timer(3.0).timeout
	var w := GameWorld.current
	w.day.day = Tour.DAYS
	w.economy.reputation = Tour.TARGETS[0] + 0.5
	w.day.auto_open = false
	w.debug_command("start_service", [])
	await get_tree().create_timer(0.3).timeout
	w.debug_command("end_service", [])
	await get_tree().create_timer(0.5).timeout
	w.debug_command("end_service", [])
	await get_tree().create_timer(0.5).timeout
	print("HOST: verdict=", w.day.last_results.get("tour", {}).get("verdict", "?"))
	Net.request("tour_next")
	await get_tree().create_timer(2.0).timeout
	w = GameWorld.current
	print("HOST: now at %s, players=%d" % [w.location.id, w.players().size()])
	await get_tree().create_timer(8.0).timeout
	Saves.delete()
	get_tree().quit()


func _client() -> void:
	await get_tree().create_timer(3.0).timeout
	main.start_join("127.0.0.1")
	var t := 0.0
	while GameWorld.current == null and t < 20.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	if GameWorld.current == null:
		print("CLIENT FAIL: never received the world")
		get_tree().quit(1)
		return
	var first := GameWorld.current
	print("CLIENT: joined at %s, tour leg %d" % [first.location.id, Tour.leg(first.tour)])
	t = 0.0
	while (GameWorld.current == first or GameWorld.current == null or GameWorld.current.location.id != &"express") and t < 25.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	await get_tree().create_timer(3.0).timeout
	var w := GameWorld.current
	var fails := 0
	if w == null or w.location.id != &"express":
		fails += 1
		print("CLIENT FAIL: didn't follow to the train")
	else:
		var mine := 0
		for p in w.players():
			if p.is_local():
				mine += 1
		if w.players().size() != 2 or mine != 1:
			fails += 1
			print("CLIENT FAIL: players %d (local %d)" % [w.players().size(), mine])
		if Tour.leg(w.tour) != 1:
			fails += 1
			print("CLIENT FAIL: tour leg %d" % Tour.leg(w.tour))
		if w.grid.all_fixtures().size() < 20:
			fails += 1
			print("CLIENT FAIL: fixtures %d" % w.grid.all_fixtures().size())
	print("CLIENT RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
