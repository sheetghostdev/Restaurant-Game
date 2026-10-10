extends Node
## Two-process test of the Morning Paper and supplier deals online.
##   godot --headless --path . res://tests/net_paper_test.tscn -- --net-host
##   godot --headless --path . res://tests/net_paper_test.tscn -- --net-client
## The host starts day 2's morning; the client must see the same paper, pick
## a story through the server, and call the supplier's rep for new deals.

var main: Node
var is_host := false


func _ready() -> void:
	is_host = "--net-host" in OS.get_cmdline_user_args()
	Saves.active_slot = "net_paper_host" if is_host else "net_paper_client"
	Saves.delete()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	if is_host:
		await _host()
	else:
		await _client()


func _host() -> void:
	main.start_host()
	var w := GameWorld.current
	w.economy.earn(500.0, "net test")
	w.day.day = 2
	w.day._begin_morning(false)
	var t := 0.0
	while Net.multiplayer.get_peers().is_empty() and t < 20.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	await get_tree().create_timer(16.0).timeout
	print("HOST: story=%s deals=%s calls=%d" % [w.day.headline().get("id", "-"), w.build.deals, w.build.rep_calls])
	get_tree().quit()


func _client() -> void:
	await get_tree().create_timer(3.0).timeout
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
	await get_tree().create_timer(3.0).timeout
	var fails := 0
	var offers: Array = w.day.paper.get("offers", [])
	var mine := MorningPaper.offers(w, 2)
	print("CLIENT: day %d, paper %s" % [w.day.day, offers.map(func(h): return h["id"])])
	if not w.day.paper_pending() or offers.size() != 3: fails += 1; print("CLIENT FAIL: the morning paper didn't arrive")
	if offers.map(func(h): return h["id"]) != mine.map(func(h): return h["id"]): fails += 1; print("CLIENT FAIL: a different paper from the host's")
	if not w.hud.paper.visible: fails += 1; print("CLIENT FAIL: the paper isn't on screen")
	if w.build.deals.size() != 3: fails += 1; print("CLIENT FAIL: supplier deals not shared")
	Net.request("headline", [1])
	await get_tree().create_timer(1.5).timeout
	if w.day.paper_pending() or String(w.day.headline().get("id", "")) != String(offers[1]["id"]): fails += 1; print("CLIENT FAIL: picking a story through the server didn't work")
	if w.hud.paper.visible: fails += 1; print("CLIENT FAIL: the paper is still on screen")
	var fd := Content.fixture(w.build.deals[0])
	var want := roundf(fd.price * BuildManager.DEAL_MULT * w.day.equip_mult())
	if w.build.price_of(fd) != want: fails += 1; print("CLIENT FAIL: deal price %s, expected %s" % [w.build.price_of(fd), want])
	var before := w.build.deals.duplicate()
	var cash := w.economy.money
	Net.request("call_rep")
	await get_tree().create_timer(1.5).timeout
	if w.build.deals == before or w.build.rep_calls != 1: fails += 1; print("CLIENT FAIL: calling the rep didn't bring new deals")
	if absf(cash - BuildManager.REP_CALL_PRICE - w.economy.money) > 0.5: fails += 1; print("CLIENT FAIL: the rep's fee wasn't paid (%.0f → %.0f)" % [cash, w.economy.money])
	print("CLIENT: story %s, deals %s → %s" % [w.day.headline().get("title", ""), before, w.build.deals])
	print("CLIENT RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
