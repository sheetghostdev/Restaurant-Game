extends Node
## Two-process network smoke test.
##   godot --headless --path . res://tests/net_test.tscn -- --net-host
##   godot --headless --path . res://tests/net_test.tscn -- --net-client
## The host opens the restaurant and spawns customers; the client checks that
## the replicated world matches (entities, players, phase, money, movement).

var main: Node
var is_host := false


func _ready() -> void:
	is_host = "--net-host" in OS.get_cmdline_user_args()
	Saves.active_slot = "net_test_host" if is_host else "net_test_client"
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
	# Open and fill the restaurant BEFORE anyone joins, so the client has to
	# rebuild a busy mid-service world from the late-join snapshot.
	w.day.open_restaurant()
	w.customers.spawn_group(Content.archetype(&"work_crew"), true)
	w.economy.earn(123.0, "net test")
	var t := 0.0
	while Net.multiplayer.get_peers().is_empty() and t < 20.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	print("HOST: peers=", Net.multiplayer.get_peers())
	await get_tree().create_timer(2.0).timeout
	# Move a crate so the client sees an item location change.
	var shelf: Fixture = w.grid.fixtures_of(&"shelf")[0]
	var crate: Item = shelf.primary_slot().item
	var hp: PlayerCharacter = w.players()[0]
	hp.hold(shelf.primary_slot().take())
	await get_tree().create_timer(10.0).timeout
	print("HOST: entities=%d players=%d customers=%d money=%.0f" % [w.entities.size(), w.players().size(), w.all_of_kind(&"customer").size(), w.economy.money])
	await get_tree().create_timer(10.0).timeout
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
	await get_tree().create_timer(12.0).timeout
	var fails := 0
	var players := w.players()
	var mine := 0
	for p in players:
		if p.is_local():
			mine += 1
	print("CLIENT: entities=%d players=%d (local %d) customers=%d phase=%s money=%.0f" % [w.entities.size(), players.size(), mine, w.all_of_kind(&"customer").size(), w.day.phase_name(), w.economy.money])
	if players.size() != 2: fails += 1; print("CLIENT FAIL: expected 2 players")
	if mine != 1: fails += 1; print("CLIENT FAIL: expected 1 local player")
	if w.day.phase != GameConst.Phase.SERVICE: fails += 1; print("CLIENT FAIL: phase not replicated")
	if w.economy.money < 370.0: fails += 1; print("CLIENT FAIL: money not replicated")
	if w.all_of_kind(&"customer").size() < 2: fails += 1; print("CLIENT FAIL: customers not replicated")
	if w.grid.all_fixtures().size() < 55: fails += 1; print("CLIENT FAIL: fixtures not replicated")
	var held_by_host := false
	for p in players:
		if not p.is_local() and p.held() is CrateItem:
			held_by_host = true
	if not held_by_host: fails += 1; print("CLIENT FAIL: host's held crate not mirrored")
	# Client-side action: stand at a stocked shelf and press GRAB. The server
	# must run the interaction and replicate the crate into our hands.
	var me: PlayerCharacter = null
	for p in players:
		if p.is_local():
			me = p
	var shelf: Fixture = null
	for f in w.grid.fixtures_of(&"shelf"):
		if f.primary_slot().item is CrateItem:
			shelf = f
			break
	if me and shelf:
		me.input_override = true
		me.global_position = GameConst.cell_center(shelf.front_cell())
		me.rotation.y = atan2(-shelf.front_vec().x, -shelf.front_vec().z)
		me.facing = -shelf.front_vec()
		await get_tree().create_timer(0.6).timeout
		me.set_input(Vector2.ZERO, true, false, false, false)
		await get_tree().create_timer(0.3).timeout
		me.set_input(Vector2.ZERO, false, false, false, false)
		await get_tree().create_timer(1.5).timeout
		if not (me.held() is CrateItem):
			fails += 1
			print("CLIENT FAIL: grabbing a crate as the client didn't work (held=%s)" % me.held())
		else:
			print("CLIENT: grabbed %s through the server" % me.held().display_name())
	var moved := false
	for c in w.all_of_kind(&"customer"):
		if (c as Node3D).global_position.distance_to(GameConst.cell_center(Vector2i(-5, 9))) > 1.5 and (c as Node3D).global_position.distance_to(GameConst.cell_center(Vector2i(29, 9))) > 1.5:
			moved = true
	if not moved: fails += 1; print("CLIENT FAIL: customers didn't move")
	if w.deliveries.standing_order.is_empty(): fails += 1; print("CLIENT FAIL: standing order not replicated")
	# Groups only exist on the server; tables mirror enough for client hints.
	var seated := 0
	for c in w.all_of_kind(&"customer"):
		if c.seated:
			seated += 1
	var tables_with_group := 0
	for f in w.grid.all_fixtures():
		var st := f.get_component("SeatingTable") as SeatingTable
		if st and not st._group_view().is_empty():
			tables_with_group += 1
			print("CLIENT: table %d says '%s'" % [st.number, st.status_text()])
	if seated > 0 and tables_with_group == 0: fails += 1; print("CLIENT FAIL: seated group not mirrored on tables")
	print("CLIENT RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
