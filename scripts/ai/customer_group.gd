class_name CustomerGroup
extends RefCounted
## Server-side brain for a party of customers. Drives the flow:
## arrive → queue → seat → browse → order → wait → eat → pay → leave
## (or get upset and walk out). Members are Customer entities.

enum State { ARRIVING, QUEUED, SEATING, BROWSING, READY, WAITING_FOOD, EATING, PAYING, LEAVING, GONE }

var id := 0
var archetype: CustomerArchetype
var members: Array[Customer] = []
var state := State.ARRIVING
var tables: Array = []            ## Fixtures of the reserved cluster
var seats: Array = []             ## [{table, side}]
var manager: CustomerManager
var patience := 1.0               ## 0..1 for the current wait
var _wait_total := 1.0
var _wait_left := 1.0
var _timer := 0.0
var _arrived := 0
var _order_time := 0.0
var satisfaction_sum := 0.0
var satisfaction_n := 0
var revenue := 0.0
var upset := false
var queue_index := -1


func world() -> GameWorld:
	return manager.world


func is_leaving() -> bool:
	return state in [State.PAYING, State.LEAVING, State.GONE]


func can_take_order() -> bool:
	return state == State.READY


func state_waiting_food() -> bool:
	return state == State.WAITING_FOOD or state == State.EATING


func status_text() -> String:
	match state:
		State.SEATING: return "Being seated"
		State.BROWSING: return "Reading the menu"
		State.READY: return "Ready to order!"
		State.WAITING_FOOD: return "Waiting for food"
		State.EATING: return "Eating"
		State.PAYING: return "Paying"
		State.LEAVING: return "Leaving"
	return ""


func _set_wait(seconds: float) -> void:
	_wait_total = maxf(seconds * archetype.patience, 1.0)
	_wait_left = _wait_total
	patience = 1.0


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------

func start(spawn: Vector3) -> void:
	state = State.ARRIVING
	_set_wait(manager.QUEUE_PATIENCE)
	_arrived = 0
	for m in members:
		m.bubble = ""
		m.mark_dirty()


func tick(delta: float) -> void:
	match state:
		State.ARRIVING, State.QUEUED:
			_tick_patience(delta * (0.6 if state == State.ARRIVING else 1.0))
		State.SEATING:
			pass
		State.BROWSING:
			_timer -= delta
			if _timer <= 0.0:
				_become_ready()
		State.READY:
			_tick_patience(delta)
		State.WAITING_FOOD, State.EATING:
			_tick_eating(delta)
			if state == State.WAITING_FOOD or _anyone_waiting():
				_tick_patience(delta)
		State.PAYING:
			_timer -= delta
			if _timer <= 0.0:
				_leave()
	_update_moods()


func _tick_patience(delta: float) -> void:
	_wait_left -= delta
	patience = clampf(_wait_left / _wait_total, 0.0, 1.0)
	if _wait_left <= 0.0:
		_get_upset()


func _update_moods() -> void:
	for m in members:
		var target := patience if state in [State.QUEUED, State.ARRIVING, State.READY, State.WAITING_FOOD, State.EATING] else m.mood
		if state == State.EATING and m.done_eating:
			target = maxf(target, 0.8)
		if absf(m.mood - target) > 0.04:
			m.mood = target
			m.mark_dirty()


# --- Queue / seating -----------------------------------------------------------

func on_reached_queue() -> void:
	_arrived += 1
	if state == State.ARRIVING and _arrived >= members.size():
		state = State.QUEUED


func seat_at(cluster_tables: Array, cluster_seats: Array) -> void:
	tables = cluster_tables
	seats = cluster_seats.slice(0, members.size())
	state = State.SEATING
	_arrived = 0
	Audio.play_at(&"door_bell", manager.front_door_pos())
	for i in members.size():
		var m := members[i]
		var seat: Dictionary = seats[i]
		var table: Fixture = seat["table"]
		var side: int = seat["side"]
		var chair: Vector2i = table.cell + SeatingTable.SIDES[side]
		var cb := func(): _member_seated(m, table, side)
		m.bubble = ""
		if not m.walk_to_cell(chair, cb):
			# No path (blocked layout): sit anyway after a moment rather than
			# freezing the group.
			_member_seated(m, table, side)


func _member_seated(m: Customer, table: Fixture, side: int) -> void:
	m.sit_at(table, side)
	m.anim = CharacterRig.Anim.SIT
	m.mark_dirty()
	_arrived += 1
	if _arrived >= members.size() and state == State.SEATING:
		state = State.BROWSING
		_timer = randf_range(3.0, 6.0) * (1.6 if archetype.id == &"tourists" else 1.0)
		for mm in members:
			mm.bubble = "think"
			mm.anim = CharacterRig.Anim.THINK
			mm.mark_dirty()


func _become_ready() -> void:
	state = State.READY
	_set_wait(manager.ORDER_PATIENCE)
	for i in members.size():
		var m := members[i]
		m.bubble = "order" if i == 0 else ""
		m.anim = CharacterRig.Anim.WAVE if i == 0 else CharacterRig.Anim.SIT
		m.mark_dirty()
	Audio.play_at(&"order_ready", members[0].global_position)


# --- Ordering -------------------------------------------------------------------

func take_order(actor: Node) -> void:
	if state != State.READY:
		return
	state = State.WAITING_FOOD
	var total_dishes := 0
	for m in members:
		m.orders = manager.choose_orders(archetype, m.is_child)
		total_dishes += m.orders.size()
		var ids := []
		for o in m.orders:
			ids.push_back(String(o["recipe"]))
			world().orders.add_order(self, m, o["recipe"])
		m.bubble = "r:" + ",".join(ids)
		m.anim = CharacterRig.Anim.SIT
		m.mark_dirty()
	_set_wait(manager.FOOD_PATIENCE + total_dishes * 9.0)
	_order_time = world().day.elapsed
	Audio.play_at(&"ui_confirm", members[0].global_position)
	world().fx.popup_text(members[0].global_position + Vector3(0, 2.0, 0), "Order up!", Pal.UI_ACCENT)


func _anyone_waiting() -> bool:
	for m in members:
		for o in m.orders:
			if not o.get("served", false):
				return true
	return false


## Finds a member at this table cluster who ordered what the dish satisfies.
## Prefers a member sitting at `near_table`.
func find_member_for(dish: DishItem, near_table: Fixture) -> Customer:
	if state != State.WAITING_FOOD and state != State.EATING:
		return null
	var best: Customer = null
	for m in members:
		if _slot_for(m, dish) == null:
			continue
		for o in m.orders:
			if o.get("served", false):
				continue
			var r := Content.recipe(o["recipe"])
			if r and RecipeManager.satisfies(r, dish):
				if best == null or m.seat_table == near_table:
					best = m
				break
	return best


func _slot_for(m: Customer, dish: DishItem) -> ItemSlot:
	if m.seat_table == null:
		return null
	var st := m.seat_table.get_component("SeatingTable") as SeatingTable
	var first := st.side_slot(m.seat_side, 1 if dish.is_mug() else 0)
	if first and first.item == null:
		return first
	var second := st.side_slot(m.seat_side, 0 if dish.is_mug() else 1)
	if second and second.item == null:
		return second
	return null


func serve(actor: Node, dish: DishItem, near_table: Fixture) -> bool:
	var m := find_member_for(dish, near_table)
	if m == null:
		return false
	var slot := _slot_for(m, dish)
	if slot == null:
		return false
	var order: Dictionary = {}
	for o in m.orders:
		if not o.get("served", false) and RecipeManager.satisfies(Content.recipe(o["recipe"]), dish):
			order = o
			break
	if order.is_empty():
		return false
	actor.take_held()
	slot.put(dish)
	dish.bump()
	dish.mark_dirty()
	var r := Content.recipe(order["recipe"])
	var q := RecipeManager.dish_quality(dish)
	var strict := archetype.strictness
	var wait_frac := patience
	if q <= 0.0:
		# Refused: burnt, raw or spoiled food.
		Audio.play_at(&"customer_angry", m.global_position)
		world().fx.popup_text(m.global_position + Vector3(0, 2.0, 0), "%s?!" % RecipeManager.worst_stage(dish), Pal.UI_BAD)
		m.mood = maxf(m.mood - 0.3, 0.0)
		_wait_left -= 10.0
		dish.make_dirty()
		world().stats_add(&"refused", 1)
		return true
	order["served"] = true
	order["quality"] = q
	var sat := clampf(q * 0.65 + wait_frac * 0.35 - strict * (1.0 - q), 0.0, 1.0)
	order["satisfaction"] = sat
	satisfaction_sum += sat
	satisfaction_n += 1
	var price := r.price * archetype.spend
	var tip := price * 0.25 * archetype.tip * sat * sat
	revenue += price + tip
	order["price"] = price
	order["tip"] = tip
	world().orders.mark_served(m, order["recipe"], q)
	Events.order_served.emit(order["recipe"], q, dish.global_position)
	Audio.play_at(&"serve", dish.global_position)
	world().fx.popup_text(m.global_position + Vector3(0, 2.0, 0), RecipeManager.quality_word(q), Pal.UI_GOOD if q >= 0.7 else Pal.UI_WARN)
	m.anim = CharacterRig.Anim.EAT
	m.eat_left = maxf(m.eat_left, r.eat_time / archetype.eat_speed)
	m.done_eating = false
	_refresh_bubble(m)
	if state == State.WAITING_FOOD:
		state = State.EATING
	# Each delivery restores a little patience for the rest of the table.
	_wait_left = minf(_wait_left + 12.0, _wait_total)
	return true


func _refresh_bubble(m: Customer) -> void:
	var ids := []
	for o in m.orders:
		if not o.get("served", false):
			ids.push_back(String(o["recipe"]))
	m.bubble = ("r:" + ",".join(ids)) if not ids.is_empty() else ""
	m.mark_dirty()


func _tick_eating(delta: float) -> void:
	var all_done := true
	for m in members:
		var waiting := false
		for o in m.orders:
			if not o.get("served", false):
				waiting = true
		if m.eat_left > 0.0:
			m.eat_left -= delta
			if m.eat_left <= 0.0 and not waiting:
				_finish_eating(m)
		elif not waiting and not m.done_eating and not m.orders.is_empty():
			_finish_eating(m)
		if not m.done_eating:
			all_done = false
	if all_done:
		_pay()


func _finish_eating(m: Customer) -> void:
	m.done_eating = true
	m.anim = CharacterRig.Anim.SIT
	m.bubble = ""
	m.mark_dirty()
	var st := m.seat_table.get_component("SeatingTable") as SeatingTable if m.seat_table else null
	if st:
		for setting in 2:
			var s := st.side_slot(m.seat_side, setting)
			if s and s.item is DishItem:
				(s.item as DishItem).make_dirty()


# --- Paying / leaving -------------------------------------------------------------

func _pay() -> void:
	state = State.PAYING
	_timer = 1.6
	var sat := satisfaction_sum / maxf(satisfaction_n, 1)
	world().economy.add_sale(revenue, members[0].global_position + Vector3(0, 1.6, 0))
	world().day.record_group(self, sat, false)
	for m in members:
		m.bubble = "pay" if m == members[0] else ("happy" if sat > 0.8 else "")
		m.anim = CharacterRig.Anim.CHEER if sat > 0.85 else CharacterRig.Anim.SIT
		m.mark_dirty()
	# Mess: families and kids leave crumbs, some spills.
	var mess_chance := archetype.mess
	for m in members:
		if m.is_child:
			mess_chance += 0.2
	if randf() < mess_chance and not tables.is_empty():
		var t: Fixture = tables[randi() % tables.size()]
		var st := t.get_component("SeatingTable") as SeatingTable
		if st:
			st.make_messy()
	if randf() < mess_chance * 0.35:
		var mm := members[randi() % members.size()]
		world().disasters.spawn_mess(&"crumbs" if randf() < 0.6 else &"spill", mm.global_position + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)))


func _get_upset() -> void:
	if upset or is_leaving():
		return
	upset = true
	var was_seated := state in [State.READY, State.WAITING_FOOD, State.EATING]
	Audio.play_at(&"customer_angry", members[0].global_position)
	world().fx.popup_text(members[0].global_position + Vector3(0, 2.1, 0), "We're leaving!", Pal.UI_BAD)
	world().orders.cancel_group(self)
	if revenue > 0.0:
		world().economy.add_sale(revenue * 0.6, members[0].global_position + Vector3(0, 1.6, 0))
	world().day.record_group(self, 0.0, true)
	for m in members:
		m.mood = 0.0
		m.bubble = "angry"
		m.anim = CharacterRig.Anim.UPSET
		m.mark_dirty()
	# Leave any served food behind as mess on the table
	if was_seated:
		for m in members:
			_finish_eating(m)
	_leave()


func _leave() -> void:
	state = State.LEAVING
	manager.release_tables(self)
	var exit_cell := manager.exit_cell()
	for m in members:
		m.seated = false
		if m.bubble == "pay" or m.bubble == "think":
			m.bubble = ""
		m.anim = CharacterRig.Anim.IDLE
		m.speed = archetype.walk_speed * (1.25 if upset else 1.0)
		var mm := m
		var cb := func(): _member_left(mm)
		if not m.walk_to_cell(exit_cell, cb):
			_member_left(m)
		m.mark_dirty()


func _member_left(m: Customer) -> void:
	members.erase(m)
	if is_instance_valid(m):
		world().despawn(m)
	if members.is_empty():
		state = State.GONE
		manager.on_group_gone(self)
