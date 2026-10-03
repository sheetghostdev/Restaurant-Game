extends Node
## Top-level scene manager: title menu ↔ running restaurant (offline, hosting
## or joined), plus clean shutdown back to the menu.

const WORLD_SCENE := preload("res://scenes/world/game_world.tscn")

var world: GameWorld
var menu: MainMenu
var _pending_client := false


func _ready() -> void:
	add_to_group(&"main")
	Net.world_init_received.connect(_on_world_init)
	Net.join_failed.connect(func(reason):
		_pending_client = false
		show_menu()
		menu.set_status(reason))
	Net.disconnected.connect(func(reason):
		_teardown_world()
		show_menu()
		menu.set_status(reason))
	var args := OS.get_cmdline_user_args()
	if "--autostart" in args:
		start_offline(false, setup_from_args())
	elif "--host" in args:
		start_host(setup_from_args())
	else:
		var ji := args.find("--join")
		if ji >= 0 and ji + 1 < args.size():
			start_join(args[ji + 1])
		else:
			show_menu()


## "--format=bar --location=main_street" on the command line (dev and tests).
static func setup_from_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		for k in ["format", "location"]:
			if a.begins_with("--%s=" % k):
				out[k] = a.split("=", true, 1)[1]
	return out


func show_menu() -> void:
	if menu == null:
		menu = MainMenu.new()
		menu.main = self
		add_child(menu)
	menu.refresh()
	Audio.set_music_state(&"menu")


func _hide_menu() -> void:
	if menu:
		menu.queue_free()
		menu = null


func _new_world() -> GameWorld:
	_teardown_world()
	world = WORLD_SCENE.instantiate()
	add_child(world)
	return world


func _teardown_world() -> void:
	Audio.stop_all_loops()
	Inputs.release_all()
	get_tree().paused = false
	if world:
		world.queue_free()
		world = null


## `setup` picks a new restaurant: {"location", "format", "name"} (defaults
## to the Corner Diner on Main Street).
func start_offline(continue_save: bool, setup := {}) -> void:
	_hide_menu()
	_launch(continue_save, setup)


func start_host(setup := {}) -> void:
	var err := Net.host()
	if err != OK:
		show_menu()
		menu.set_status("Could not host (port %d busy?)" % Net.DEFAULT_PORT)
		return
	_hide_menu()
	_launch(setup.is_empty() and Saves.has_save(), setup)
	Events.notify("Hosting on port %d — friends can join with your IP" % Net.DEFAULT_PORT, &"info")


func start_join(address: String) -> void:
	var err := Net.join(address)
	if err != OK:
		show_menu()
		menu.set_status("Could not connect to %s" % address)
		return
	_pending_client = true
	if menu:
		menu.set_status("Connecting to %s…" % address)


func _on_world_init(meta: Dictionary, layout: Dictionary) -> void:
	if not _pending_client:
		return
	_pending_client = false
	_hide_menu()
	var w := _new_world()
	w.start_client(meta, layout)


func _launch(continue_save: bool, setup := {}) -> void:
	var w := _new_world()
	var data := Saves.load_data() if continue_save else {}
	if not data.is_empty():
		w.load_save(data)
	else:
		var fmt := StringName(setup.get("format", "diner"))
		var loc := StringName(setup.get("location", "main_street"))
		if not Content.formats.has(fmt):
			fmt = &"diner"
		if not Content.locations.has(loc):
			loc = &"main_street"
		w.start_new(loc, fmt, String(setup.get("name", "")))
	w.add_local_player(Inputs.KB_A)
	if "--coop-test" in OS.get_cmdline_user_args():
		w.add_local_player(Inputs.KB_B)


func return_to_menu() -> void:
	if world and Net.is_authority() and world.day.phase != GameConst.Phase.RESULTS:
		Saves.save_game(world)
	_teardown_world()
	Net.leave()
	show_menu()


func debug_reset() -> void:
	var setup := {}
	if world and world.format and world.location:
		setup = {"location": String(world.location.id), "format": String(world.format.id), "name": world.restaurant_name}
	Saves.delete()
	_teardown_world()
	if Net.is_online():
		Net.leave()
	start_offline(false, setup)
