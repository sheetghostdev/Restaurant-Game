class_name StaffBrain
## Decision rules for each staff role. Each returns the next task:
## {target: Node, verb: Verb, label: String} or {} when there's nothing to do.


static func next_task(w: Worker) -> Dictionary:
	match w.role:
		&"dishwasher": return _dishwasher(w)
		&"busser": return _busser(w)
		&"server": return _server(w)
		&"stocker": return _stocker(w)
	return {}


static func access_cell(world: GameWorld, target: Node3D, from: Vector3) -> Vector2i:
	var g := world.grid
	if target is Fixture:
		var f := target as Fixture
		var best := Vector2i(-9999, -9999)
		var best_d := INF
		var cands: Array[Vector2i] = [f.front_cell()]
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			cands.push_back(f.cell + d)
		for c in cands:
			if not g.walkable(c) or g.wall_between(f.cell, c):
				continue
			var dd := GameConst.cell_center(c).distance_to(from) + (0.0 if c == f.front_cell() else 0.6)
			if dd < best_d:
				best_d = dd
				best = c
		return best
	return GameConst.world_to_cell(target.global_position)


static func _fixtures(w: Worker, comp: String) -> Array:
	var out := []
	for f in w.world.grid.all_fixtures():
		if f.get_component(comp) and not f.is_blocked():
			out.push_back(f)
	out.sort_custom(func(a, b): return a.global_position.distance_to(w.global_position) < b.global_position.distance_to(w.global_position))
	return out


static func _t(target: Node, verb: int, label: String) -> Dictionary:
	return {"target": target, "verb": verb, "label": label}


static func _put_away(w: Worker, held: Item) -> Dictionary:
	var d := held as DishItem
	if d and not d.dirty and d.contents.is_empty():
		for f in _fixtures(w, "DishRack"):
			var r := f.get_component("DishRack") as DishRack
			if ((r.kind == "plate" and d.plates > 0) or (r.kind == "mug" and d.mugs > 0)) and r.count < r.capacity:
				return _t(f, GameConst.Verb.GRAB, "Putting dishes away")
	if d and d.dirty:
		for f in _fixtures(w, "Dishwasher"):
			var dw := f.get_component("Dishwasher") as Dishwasher
			if dw.state == Dishwasher.State.LOADING and dw.total() + d.count() <= dw.capacity and f.is_working():
				return _t(f, GameConst.Verb.GRAB, "Loading the dishwasher")
		for f in _fixtures(w, "Sink"):
			var s := f.get_component("Sink") as Sink
			if s.dirty_total() + d.count() <= s.capacity:
				return _t(f, GameConst.Verb.GRAB, "Dropping off dishes")
	# Can't put it anywhere sensible: set it down on a free counter.
	for f in w.world.grid.all_fixtures():
		if f.def_id == &"counter" and f.primary_slot() and f.primary_slot().item == null:
			return _t(f, GameConst.Verb.GRAB, "Setting it down")
	return {}


static func _dishwasher(w: Worker) -> Dictionary:
	var held := w.held()
	if held:
		return _put_away(w, held)
	for f in _fixtures(w, "Dishwasher"):
		var dw := f.get_component("Dishwasher") as Dishwasher
		if dw.state == Dishwasher.State.DONE:
			return _t(f, GameConst.Verb.GRAB, "Unloading the dishwasher")
		if dw.state == Dishwasher.State.LOADING and dw.total() > 0 and f.is_working():
			# Start a half-full load if the racks are running low.
			var low := true
			for rf in _fixtures(w, "DishRack"):
				if (rf.get_component("DishRack") as DishRack).count > 3:
					low = false
			if low:
				return _t(f, GameConst.Verb.USE, "Starting the dishwasher")
	for f in _fixtures(w, "Sink"):
		var s := f.get_component("Sink") as Sink
		if s.dirty_total() > 0:
			return _t(f, GameConst.Verb.USE, "Washing dishes")
		if s.clean_total() > 0:
			return _t(f, GameConst.Verb.GRAB, "Collecting clean dishes")
	return {}


static func _busser(w: Worker) -> Dictionary:
	var held := w.held()
	if held:
		if held is DishItem and (held as DishItem).dirty and held.count() < 6:
			var more := _dirty_table(w)
			if not more.is_empty():
				return more
		return _put_away(w, held)
	var t := _dirty_table(w)
	if not t.is_empty():
		return t
	for f in _fixtures(w, "SeatingTable"):
		var st := f.get_component("SeatingTable") as SeatingTable
		var g := st.group()
		if st.messy and (g == null or g.is_leaving()):
			return _t(f, GameConst.Verb.USE, "Wiping a table")
	return {}


static func _dirty_table(w: Worker) -> Dictionary:
	for f in _fixtures(w, "SeatingTable"):
		var st := f.get_component("SeatingTable") as SeatingTable
		if st.has_dirty_dishes():
			return _t(f, GameConst.Verb.GRAB, "Clearing a table")
	return {}


static func _server(w: Worker) -> Dictionary:
	for f in _fixtures(w, "SeatingTable"):
		var st := f.get_component("SeatingTable") as SeatingTable
		var g := st.group()
		if g and g.can_take_order():
			return _t(f, GameConst.Verb.USE, "Taking an order")
	return _busser(w)


static func _stocker(w: Worker) -> Dictionary:
	var held := w.held()
	var world := w.world
	if held is CrateItem:
		var cr := held as CrateItem
		if cr.count <= 0:
			# Empties go back to the dock.
			return {}
		var want_cold := cr.content_def() != null and cr.content_def().perishable
		for f in world.grid.all_fixtures():
			var s: ItemSlot = f.primary_slot()
			if s == null or s.item != null or not s.accepts_item(cr):
				continue
			if f.def.category != "storage":
				continue
			if want_cold and not s.cold:
				continue
			return _t(f, GameConst.Verb.GRAB, "Stocking shelves")
		if want_cold:
			for f2 in world.grid.all_fixtures():
				var s2: ItemSlot = f2.primary_slot()
				if s2 and s2.item == null and f2.def.category == "storage" and s2.accepts_item(cr):
					return _t(f2, GameConst.Verb.GRAB, "Stocking shelves")
		return {}
	if held:
		return {}
	# Find a delivered crate on the floor.
	for it in world.items_root.get_children():
		if it is CrateItem and (it as CrateItem).count > 0:
			return {"target": it, "verb": GameConst.Verb.GRAB, "label": "Unloading the delivery"}
	return {}
