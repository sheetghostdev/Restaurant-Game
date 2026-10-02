class_name OrderManager
extends Node
## Active order tickets. The authority keeps the canonical list; a compact
## ticket list is replicated to clients for the HUD rail.

var world: GameWorld
var orders: Array = []      ## server: [{id, group, member, recipe, table, created}]
var tickets: Array = []     ## all peers: [{id, recipe, table, patience, served}]
var _next := 1
var _sync_t := 0.0


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld


func add_order(g: CustomerGroup, m: Customer, recipe: StringName) -> void:
	var table := 0
	if m.seat_table:
		var st := m.seat_table.get_component("SeatingTable") as SeatingTable
		table = st.number if st else 0
	orders.push_back({"id": _next, "group": g, "member": m, "recipe": recipe, "table": table, "created": world.day.elapsed})
	_next += 1
	_publish()


func mark_served(m: Customer, recipe: StringName, _quality: float) -> void:
	for i in orders.size():
		var o: Dictionary = orders[i]
		if o["member"] == m and o["recipe"] == recipe:
			orders.remove_at(i)
			break
	_publish()


func cancel_group(g: CustomerGroup) -> void:
	var n := 0
	for i in range(orders.size() - 1, -1, -1):
		if orders[i]["group"] == g:
			orders.remove_at(i)
			n += 1
	if n > 0:
		world.day.stats_add(&"orders_missed", n)
	_publish()


func clear() -> void:
	orders.clear()
	_publish()


func pending_count(recipe: StringName = &"") -> int:
	if recipe == &"":
		return tickets.size()
	var n := 0
	for t in tickets:
		if StringName(t["recipe"]) == recipe:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	if not Net.is_authority() or world == null:
		return
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.5
		_publish()


func _publish() -> void:
	if not Net.is_authority():
		return
	var out := []
	for o in orders:
		var g: CustomerGroup = o["group"]
		out.push_back({
			"id": o["id"],
			"recipe": String(o["recipe"]),
			"table": o["table"],
			"patience": snappedf(g.patience if g else 1.0, 0.02),
		})
	tickets = out
	if world.replicator:
		world.replicator.publish(&"orders", {"t": out})
	Events.orders_changed.emit()


func apply_shared(d: Dictionary) -> void:
	tickets = d.get("t", [])
	Events.orders_changed.emit()
