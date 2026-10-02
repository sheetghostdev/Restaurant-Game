class_name DeliveryManager
extends Node
## Physical deliveries. A truck brings the standing order every morning and
## drops crates on the loading dock — they're in the way until somebody
## carries them inside. Rush orders and equipment arrive by van, sometimes in
## the middle of service.

const RUSH_MARKUP := 1.5
const RUSH_DELAY := 22.0
const PACKAGE_DELAY := 6.0
const EMPTY_DEPOSIT := 1.0

var world: GameWorld
var standing_order := {}     ## supply_id -> crates per morning
var pending: Array = []      ## [{at: float, vehicle: "truck"|"van", items: [...], label}]
var _clock := 0.0
var _active: DeliveryTruck


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld


func _default_order() -> void:
	standing_order.clear()
	for s in Content.supplies.values():
		if s.default_order > 0:
			standing_order[s.id] = s.default_order


func save_data() -> Dictionary:
	var so := {}
	for k in standing_order:
		so[String(k)] = standing_order[k]
	# Deliveries still on the road (including the truck currently unloading)
	# are saved so nothing paid for is lost.
	var road := []
	for d in pending:
		road.push_back({"vehicle": d["vehicle"], "items": d["items"], "label": d["label"]})
	if _active and is_instance_valid(_active) and not _active.items.is_empty():
		road.push_back({"vehicle": _active.vehicle, "items": _active.items, "label": "Delivery"})
	return {"standing_order": so, "pending": road}


func load_data(d: Dictionary) -> void:
	standing_order.clear()
	var so: Dictionary = d.get("standing_order", {})
	for k in so:
		standing_order[StringName(k)] = int(so[k])
	if standing_order.is_empty():
		_default_order()
	pending.clear()
	for r in d.get("pending", []):
		pending.push_back({"at": _clock + 2.0, "vehicle": r.get("vehicle", "truck"), "items": r.get("items", []), "label": r.get("label", "Delivery")})


func standing_order_cost() -> float:
	var total := 0.0
	for k in standing_order:
		var s := Content.supply(k)
		if s:
			total += s.price * standing_order[k]
	return total


func set_standing(supply_id: StringName, crates: int) -> void:
	standing_order[supply_id] = clampi(crates, 0, 9)
	world.replicator.publish(&"standing", {"o": _so_strings()})


func _so_strings() -> Dictionary:
	var out := {}
	for k in standing_order:
		out[String(k)] = standing_order[k]
	return out


func apply_shared_standing(d: Dictionary) -> void:
	standing_order.clear()
	var o: Dictionary = d.get("o", {})
	for k in o:
		standing_order[StringName(k)] = int(o[k])


# -----------------------------------------------------------------------------
# Scheduling
# -----------------------------------------------------------------------------

func morning_delivery(first_day: bool) -> void:
	if standing_order.is_empty():
		_default_order()
	var items := []
	var cost := 0.0
	for k in standing_order:
		var s := Content.supply(k)
		if s == null:
			continue
		for i in standing_order[k]:
			items.push_back({"supply": String(k)})
			cost += s.price
	if items.is_empty():
		return
	if first_day:
		Events.notify("Opening stock — on the house!", &"info")
	else:
		world.economy.charge(cost, "Morning delivery")
	pending.push_back({"at": _clock + 2.0, "vehicle": "truck", "items": items, "label": "Morning delivery"})


func rush_order(supply_id: StringName, crates := 1) -> bool:
	var s := Content.supply(supply_id)
	if s == null:
		return false
	var cost := s.price * crates * RUSH_MARKUP
	if not world.economy.spend(cost, "Rush order: %s" % s.display_name):
		return false
	var items := []
	for i in crates:
		items.push_back({"supply": String(supply_id)})
	pending.push_back({"at": _clock + RUSH_DELAY, "vehicle": "van", "items": items, "label": "Rush order"})
	Events.notify("Rush order placed — arriving soon", &"info")
	return true


func order_package(fixture_id: StringName) -> void:
	pending.push_back({"at": _clock + PACKAGE_DELAY, "vehicle": "van", "items": [{"package": String(fixture_id)}], "label": "Equipment delivery"})


## Extra delivery mid-service (events).
func schedule_extra(items: Array, delay: float, label: String) -> void:
	pending.push_back({"at": _clock + delay, "vehicle": "truck", "items": items, "label": label})


func on_closing() -> void:
	pass


func _physics_process(delta: float) -> void:
	if world == null or not Net.is_authority():
		return
	_clock += delta
	if _active and is_instance_valid(_active):
		return
	_active = null
	for i in pending.size():
		if pending[i]["at"] <= _clock:
			var d: Dictionary = pending[i]
			pending.remove_at(i)
			_dispatch(d)
			break


func _dispatch(d: Dictionary) -> void:
	var path: Array = world.grid.street.get("truck_path", [])
	if path.size() < 2:
		# No road: drop immediately.
		_drop_all(d["items"])
		return
	var t: DeliveryTruck = world.spawn_entity(&"truck", StringName(d["vehicle"]), {"v": d["vehicle"]}, {"pos": [path[0][0], 0, path[0][1]], "yaw": 0.0})
	t.manager = self
	t.items = d["items"]
	t.start(path)
	_active = t
	Audio.play_at(&"truck_horn", t.global_position)
	if world.day.phase == GameConst.Phase.SERVICE:
		Events.notify("%s arriving at the dock!" % d["label"], &"warning")


func _drop_all(items: Array) -> void:
	for it in items:
		drop_one(it)


## Places one delivered thing on the dock (or the nearest free spot).
func drop_one(entry: Dictionary) -> Item:
	var spot := _free_dock_spot()
	var loc := {"floor": [spot.x, 0.0, spot.z, randf_range(-0.15, 0.15)]}
	var it: Item = null
	if entry.has("supply"):
		it = world.spawn_crate(StringName(entry["supply"]), -1, loc)
	elif entry.has("package"):
		it = world.spawn_package(StringName(entry["package"]), loc)
	if it:
		it.bump()
		Audio.play_at(&"drop_heavy", spot)
		world.fx.dust(spot)
	return it


func _free_dock_spot() -> Vector3:
	var occupied := func(p: Vector3) -> bool:
		for o in world.items_root.get_children():
			if o is Item and (o as Item).global_position.distance_to(p) < 0.5:
				return true
		return false
	for c in world.grid.delivery_zone:
		var p := GameConst.cell_center(c)
		if not occupied.call(p):
			return p
	# Overflow: spiral out from the dock into whatever floor is free.
	var origin: Vector2i = world.grid.delivery_zone[0] if not world.grid.delivery_zone.is_empty() else Vector2i.ZERO
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var c := origin + Vector2i(dx, dz)
				if not world.grid.walkable(c) or not world.grid.in_lot(c):
					continue
				var p2 := GameConst.cell_center(c)
				if not occupied.call(p2):
					return p2
	return GameConst.cell_center(origin) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))


## The driver takes empty crates left in the loading zone.
func collect_empties() -> void:
	var n := 0
	for o in world.items_root.get_children():
		if o is CrateItem and (o as CrateItem).count <= 0:
			var c := GameConst.world_to_cell((o as CrateItem).global_position)
			var rt := world.grid.room_type_at(c)
			if c in world.grid.delivery_zone or (rt and rt.id == &"loading"):
				n += 1 + (o as CrateItem).empties
				world.despawn(o)
	if n > 0:
		world.economy.earn(n * EMPTY_DEPOSIT, "Crate deposits")
		Events.notify("Driver collected %d empty crates (+%s)" % [n, GameConst.money(n * EMPTY_DEPOSIT)], &"info")


func is_busy() -> bool:
	return _active != null and is_instance_valid(_active)
