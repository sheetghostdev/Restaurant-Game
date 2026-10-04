extends Node
## Two-process network test of the train: the client sees the timetable,
## the market stalls and the doors lock when the train leaves.
##   godot --headless --path . res://tests/net_theme_test.tscn -- --net-host
##   godot --headless --path . res://tests/net_theme_test.tscn -- --net-client

var main: Node
var is_host := false


func _ready() -> void:
	is_host = "--net-host" in OS.get_cmdline_user_args()
	Saves.active_slot = "net_theme_host" if is_host else "net_theme_client"
	Saves.delete()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	if is_host:
		await _host()
	else:
		await _client()


func _host() -> void:
	main.start_host({"location": "express", "format": "pizza_parlor"})
	var w := GameWorld.current
	var t := 0.0
	while Net.multiplayer.get_peers().is_empty() and t < 20.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	print("HOST: peers=", Net.multiplayer.get_peers(), " stalls=", w.grid.fixtures_of(&"market_stall").size())
	await get_tree().create_timer(8.0).timeout
	w.day.open_restaurant()
	print("HOST: departing")
	await get_tree().create_timer(14.0).timeout
	get_tree().quit()


func _client() -> void:
	await get_tree().create_timer(4.0).timeout
	main.start_join("127.0.0.1")
	var t := 0.0
	while GameWorld.current == null and t < 20.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	var w := GameWorld.current
	if w == null:
		print("CLIENT FAIL: never received the world")
		get_tree().quit(1)
		return
	await get_tree().create_timer(4.0).timeout
	var fails := 0
	var tl := w.theme_node as TrainLine
	if tl == null: fails += 1; print("CLIENT FAIL: no train on the client")
	if w.format.id != &"pizza_parlor": fails += 1; print("CLIENT FAIL: wrong restaurant type ", w.format.id)
	var stalls := w.grid.fixtures_of(&"market_stall").size()
	print("CLIENT: stalls=%d station=%s" % [stalls, tl.station if tl else "?"])
	if stalls != Content.supplies_for(w.format).size(): fails += 1; print("CLIENT FAIL: market stalls not replicated")
	if w.grid.locked.has("train_door"): fails += 1; print("CLIENT FAIL: doors locked at the depot")
	var ms := w.grid.fixtures_of(&"market_stall")[0].get_component("MarketStall") as MarketStall if stalls > 0 else null
	if ms and ms.supply_id == &"": fails += 1; print("CLIENT FAIL: stall state not replicated")
	await get_tree().create_timer(12.0).timeout
	print("CLIENT: state=%s doors_locked=%s stalls=%d line=%s" % [tl.state if tl else -1, w.grid.locked.has("train_door"), w.grid.fixtures_of(&"market_stall").size(), tl.status_line() if tl else ""])
	if tl and tl.state == TrainLine.State.STOPPED: fails += 1; print("CLIENT FAIL: train never left")
	if not w.grid.locked.has("train_door"): fails += 1; print("CLIENT FAIL: doors not locked while moving")
	if not w.grid.fixtures_of(&"market_stall").is_empty(): fails += 1; print("CLIENT FAIL: stalls still there")
	print("CLIENT RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	get_tree().quit(1 if fails > 0 else 0)
