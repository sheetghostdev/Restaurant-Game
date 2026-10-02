extends Node
## Autoload "Net": multiplayer session management and RPC endpoints.
##
## Model: the host is authoritative for all gameplay. Clients move their own
## player locally (for responsiveness) and send position + button state; the
## server runs every interaction and replicates the results. Offline play uses
## Godot's OfflineMultiplayerPeer, where this peer is the authority, so the
## same code path runs in single player, local co-op and online games.

signal hosted
signal joined                       ## client: connection established
signal join_failed(reason: String)
signal disconnected(reason: String)
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal world_init_received(meta: Dictionary, layout: Dictionary)

const DEFAULT_PORT := 24680
const MAX_CLIENTS := 5

var online := false
var player_name := "Chef"
## Input device for this machine's player when joining someone else's game.
var local_device := 0
var _motion_t := 0.0
var _last_buttons := {}
var _peer_names := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func is_authority() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func is_online() -> bool:
	return online


func my_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()


func host(port := DEFAULT_PORT) -> Error:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	online = true
	hosted.emit()
	return OK


func join(address: String, port := DEFAULT_PORT) -> Error:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	online = true
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	_last_buttons.clear()


func _on_peer_connected(id: int) -> void:
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	_peer_names.erase(id)
	peer_disconnected.emit(id)
	var w := GameWorld.current
	if w and is_authority():
		for p in w.players():
			if p.peer_id == id:
				if p.held():
					var it: Item = p.take_held()
					it.place_on_floor(p.global_position)
				if p.carried_fixture:
					w.build.drop_carried(p)
				w.despawn(p)
				Events.notify("A player left", &"info")


func _on_connected() -> void:
	joined.emit()
	_c_hello.rpc_id(1, player_name)


func _on_failed() -> void:
	online = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	join_failed.emit("Could not connect")


func _on_server_gone() -> void:
	online = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	disconnected.emit("The host closed the game")


# -----------------------------------------------------------------------------
# Client -> server
# -----------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _c_hello(pname: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	_peer_names[id] = pname
	var w := GameWorld.current
	if w == null:
		return
	_s_world_init.rpc_id(id, w.client_init_meta(), w.grid.save_layout())
	w.replicator.send_snapshot(id)
	w.add_remote_player(id, pname)
	Events.notify("%s joined!" % pname, &"info")


## Called every physics frame for local players on a client.
func send_player_state(p: Node) -> void:
	_motion_t += get_physics_process_delta_time()
	if _motion_t >= 1.0 / 30.0:
		_motion_t = 0.0
		_c_motion.rpc_id(1, p.net_id, p.global_position.x, p.global_position.z, p.rotation.y, p.input_move.x, p.input_move.y)


func send_buttons(p: Node) -> void:
	var key := [p.in_grab, p.in_use, p.in_alt, p.in_sprint]
	if _last_buttons.get(p.net_id) == key:
		return
	_last_buttons[p.net_id] = key
	_c_buttons.rpc_id(1, p.net_id, p.in_grab, p.in_use, p.in_alt, p.in_sprint)


func _owned_player(net_id: int) -> PlayerCharacter:
	var w := GameWorld.current
	if w == null:
		return null
	var p := w.get_entity(net_id) as PlayerCharacter
	if p == null or p.peer_id != multiplayer.get_remote_sender_id():
		return null
	return p


@rpc("any_peer", "unreliable_ordered")
func _c_motion(net_id: int, x: float, z: float, yaw: float, mx: float, my: float) -> void:
	var p := _owned_player(net_id)
	if p == null:
		return
	p.apply_remote_motion(Vector3(x, 0, z), yaw)
	p.input_move = Vector2(mx, my)


@rpc("any_peer", "reliable")
func _c_buttons(net_id: int, grab: bool, use: bool, alt: bool, sprint: bool) -> void:
	var p := _owned_player(net_id)
	if p == null:
		return
	p.set_input(p.input_move, grab, use, alt, sprint)


## UI actions (catalog purchases, standing order, results continue...).
func request(action: String, args: Array = []) -> void:
	if is_authority():
		_do_request(action, args, my_id())
	else:
		_c_request.rpc_id(1, action, args)


@rpc("any_peer", "reliable")
func _c_request(action: String, args: Array) -> void:
	if multiplayer.is_server():
		_do_request(action, args, multiplayer.get_remote_sender_id())


func _do_request(action: String, args: Array, _from: int) -> void:
	var w := GameWorld.current
	if w == null:
		return
	match action:
		"buy_fixture": w.build.buy_fixture(StringName(args[0]))
		"buy_upgrade": w.build.buy_upgrade(StringName(args[0]))
		"buy_expansion": w.build.buy_expansion(StringName(args[0]))
		"hire": w.staff.hire(StringName(args[0]))
		"dismiss":
			var wk := w.get_entity(int(args[0])) as Worker
			if wk:
				w.staff.dismiss(wk)
		"rush_order": w.deliveries.rush_order(StringName(args[0]), int(args[1]) if args.size() > 1 else 1)
		"standing": w.deliveries.adjust_standing(StringName(args[0]), clampi(int(args[1]), -9, 9))
		"continue_results": w.day.continue_from_results()
		"save": Saves.save_game(w)
		"debug": w.debug_command(String(args[0]), args.slice(1))


# -----------------------------------------------------------------------------
# Server -> clients
# -----------------------------------------------------------------------------

func open_catalog_for(actor: Node) -> void:
	if not (actor is PlayerCharacter):
		return
	var p := actor as PlayerCharacter
	if p.is_local():
		Events.catalog_requested.emit(p)
	elif online:
		_s_open_catalog.rpc_id(p.peer_id, p.net_id)


@rpc("authority", "reliable")
func _s_open_catalog(net_id: int) -> void:
	var w := GameWorld.current
	if w:
		var p := w.get_entity(net_id)
		if p:
			Events.catalog_requested.emit(p)


@rpc("authority", "reliable")
func _s_world_init(meta: Dictionary, layout: Dictionary) -> void:
	world_init_received.emit(meta, layout)


func relay_fx(method: StringName, args: Array) -> void:
	_s_fx.rpc(String(method), args)


@rpc("authority", "unreliable")
func _s_fx(method: String, args: Array) -> void:
	var w := GameWorld.current
	if w and w.fx and w.fx.has_method(method):
		var a := args.duplicate()
		a.push_back(true)
		w.fx.callv(method, a)


func relay_sfx(name: StringName, pos: Vector3, vol: float, pitch: float) -> void:
	_s_sfx.rpc(String(name), pos, vol, pitch)


@rpc("authority", "unreliable")
func _s_sfx(name: String, pos: Vector3, vol: float, pitch: float) -> void:
	Audio.play_at(StringName(name), pos, vol, pitch, true)


@rpc("authority", "reliable")
func _s_toast(text: String, kind: String, color: Color) -> void:
	Events.toast.emit(text, StringName(kind), color)


func relay_toast(text: String, kind: StringName, color: Color) -> void:
	if online and is_authority():
		_s_toast.rpc(text, String(kind), color)


# Replication channels (called by Replicator) -------------------------------------

@rpc("authority", "reliable")
func _s_spawn(records: Array) -> void:
	var w := GameWorld.current
	if w:
		w.replicator.apply_spawns(records)


@rpc("authority", "reliable")
func _s_despawn(ids: Array) -> void:
	var w := GameWorld.current
	if w:
		w.replicator.apply_despawns(ids)


@rpc("authority", "reliable")
func _s_state(batch: Array) -> void:
	var w := GameWorld.current
	if w:
		w.replicator.apply_states(batch)


@rpc("authority", "unreliable_ordered")
func _s_motion(batch: Array) -> void:
	var w := GameWorld.current
	if w:
		w.replicator.apply_motion(batch)


@rpc("authority", "reliable")
func _s_shared(key: String, data: Dictionary) -> void:
	var w := GameWorld.current
	if w:
		w.replicator.apply_shared(StringName(key), data)
