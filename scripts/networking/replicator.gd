class_name Replicator
extends Node
## Ships authoritative world state to clients.
##
## Channels:
##   spawn / despawn  — reliable, flushed every physics frame
##   state            — reliable, entities marked dirty, ~15 Hz
##   motion           — unreliable, moving actors and vehicles, ~20 Hz
##   shared           — reliable, manager state (day, economy, orders, layout...)
## The same entity records are used for late-join snapshots and save files.

const STATE_HZ := 15.0
const MOTION_HZ := 20.0

var world: GameWorld
var shared := {}           ## latest published manager states (for snapshots)
var _dirty := {}
var _spawns: Array = []
var _despawns: Array = []
var _shared_dirty := {}
var _state_t := 0.0
var _motion_t := 0.0
var _last_motion := {}


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld


func _active() -> bool:
	return Net.is_online() and Net.is_authority()


func record(e: Node) -> Dictionary:
	return {"k": String(e.get_kind()), "id": e.net_id, "def": String(e.def_id), "st": e.get_state(), "loc": e.get_location()}


func on_spawned(e: Node) -> void:
	if _active():
		_spawns.push_back(e)


func on_despawned(e: Node) -> void:
	if not _active():
		return
	var id: int = e.net_id
	_dirty.erase(id)
	for i in range(_spawns.size() - 1, -1, -1):
		if _spawns[i] == e:
			_spawns.remove_at(i)
			return
	_despawns.push_back(id)


func mark_dirty(e: Node) -> void:
	if _active() and e.net_id != 0:
		_dirty[e.net_id] = e


func publish(key: StringName, data: Dictionary) -> void:
	shared[key] = data
	if _active():
		_shared_dirty[key] = data


func _physics_process(delta: float) -> void:
	if not _active():
		return
	if not _spawns.is_empty():
		var recs := []
		for e in _spawns:
			if is_instance_valid(e):
				recs.push_back(record(e))
				_dirty.erase(e.net_id)
		_spawns.clear()
		if not recs.is_empty():
			Net._s_spawn.rpc(recs)
	if not _despawns.is_empty():
		# State first: an item dropped by a leaving player (or a fixture it was
		# carrying) must reach the floor on clients before its holder is freed.
		_flush_state()
		Net._s_despawn.rpc(_despawns.duplicate())
		_despawns.clear()
	if not _shared_dirty.is_empty():
		for k in _shared_dirty:
			Net._s_shared.rpc(String(k), _shared_dirty[k])
		_shared_dirty.clear()
	_state_t -= delta
	if _state_t <= 0.0 and not _dirty.is_empty():
		_flush_state()
	_motion_t -= delta
	if _motion_t <= 0.0:
		_motion_t = 1.0 / MOTION_HZ
		var mb := []
		for g in [&"players", &"customers", &"staff", &"vehicles"]:
			for n in get_tree().get_nodes_in_group(g):
				if not n.has_method("get_motion"):
					continue
				var m: Array = n.get_motion()
				if _last_motion.get(n.net_id) == m:
					continue
				_last_motion[n.net_id] = m
				var row := [n.net_id]
				row.append_array(m)
				mb.push_back(row)
		if not mb.is_empty():
			Net._s_motion.rpc(mb)


func _flush_state() -> void:
	_state_t = 1.0 / STATE_HZ
	var batch := []
	for id in _dirty:
		var e = _dirty[id]
		if is_instance_valid(e):
			batch.push_back([id, e.get_state(), e.get_location()])
	_dirty.clear()
	if not batch.is_empty():
		Net._s_state.rpc(batch)


## Full world for a newly joined peer.
func send_snapshot(peer: int) -> void:
	var recs := []
	for id in world.entities:
		var e = world.entities[id]
		if is_instance_valid(e):
			recs.push_back(record(e))
	recs.sort_custom(func(a, b): return GameWorld.KIND_ORDER.find(a["k"]) < GameWorld.KIND_ORDER.find(b["k"]))
	Net._s_spawn.rpc_id(peer, recs)
	for k in shared:
		Net._s_shared.rpc_id(peer, String(k), shared[k])


# -----------------------------------------------------------------------------
# Client side
# -----------------------------------------------------------------------------

func apply_spawns(records: Array) -> void:
	var deferred_items := []
	for r in records:
		var id := int(r["id"])
		if world.get_entity(id):
			continue
		if r["k"] == "item":
			deferred_items.push_back(r)
			continue
		world.spawn_entity(StringName(r["k"]), StringName(r["def"]), r.get("st", {}), r.get("loc", {}), id)
	# Items last so their holders exist.
	for r in deferred_items:
		world.spawn_entity(&"item", StringName(r["def"]), r.get("st", {}), r.get("loc", {}), int(r["id"]))
	# Late join: fixtures someone is carrying can only attach once both the
	# fixture and its carrier are in the tree.
	for r in records:
		if r["k"] == "fixture" and (r.get("loc", {}) as Dictionary).has("carried"):
			var f := world.get_entity(int(r["id"]))
			if f:
				f.set_location(r["loc"])


func apply_despawns(ids: Array) -> void:
	for id in ids:
		var e := world.get_entity(int(id))
		if e:
			world.despawn(e)


func apply_states(batch: Array) -> void:
	for row in batch:
		var e := world.get_entity(int(row[0]))
		if e == null:
			continue
		e.set_state(row[1])
		if not (e is PlayerCharacter):
			e.set_location(row[2])


func apply_motion(batch: Array) -> void:
	for row in batch:
		var e := world.get_entity(int(row[0]))
		if e and e.has_method("apply_motion"):
			e.apply_motion((row as Array).slice(1))


func apply_shared(key: StringName, data: Dictionary) -> void:
	shared[key] = data
	match key:
		&"day": world.day.apply_shared(data)
		&"economy": world.economy.apply_shared(data)
		&"orders": world.orders.apply_shared(data)
		&"inventory": world.inventory.apply_shared(data)
		&"forecast": world.disasters.apply_shared_forecast(data)
		&"standing": world.deliveries.apply_shared_standing(data)
		&"menu": world.orders.apply_shared_menu(data)
		&"power": world.disasters.apply_shared_power(data)
		&"results": Events.day_results.emit(data)
		&"layout":
			world.grid.load_layout(data)
