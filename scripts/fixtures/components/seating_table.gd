class_name SeatingTable
extends FixtureComponent
## A dining table. Adjacent tables form a cluster that seats one group, so
## players can push tables together for big families. Chairs facing a table
## side become seats; each side has a food and a drink place setting (slots).
##
## Players interact with tables to take orders (USE), serve dishes (GRAB),
## clear dirty dishes (GRAB) and wipe crumbs (hold USE).

const SIDES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var number := 0
var messy := false
var wipe := 0.0
var _view := {}        ## seated group as clients see it (see _group_view)
var _crumbs: Node3D
var _number_label: Label3D


func _ready() -> void:
	# Big enough to match a ticket ("TABLE 3") to its table from the camera.
	_number_label = Label3D.new()
	_number_label.font = load("res://art/fonts/AlfaSlabOne-Regular.ttf")
	_number_label.font_size = 72
	_number_label.pixel_size = 0.005
	_number_label.modulate = Pal.UI_INK
	_number_label.outline_size = 18
	_number_label.outline_modulate = Pal.UI_PAPER
	_number_label.position = Vector3(0.3, 0.98, -0.3)
	_number_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	fixture.add_child.call_deferred(_number_label)
	var stand := Models.instance(&"table_number")
	stand.position = Vector3(0.3, 0.72, -0.3)
	fixture.add_child.call_deferred(stand)


## Slot for a given world side (0..3) and setting (0 food, 1 drink).
func side_slot(side: int, setting: int) -> ItemSlot:
	# Slots are authored in table-local space; convert world side to local.
	var local_side := posmod(side - _side_shift(), 4)
	return fixture.slot(local_side * 2 + setting)


func _side_shift() -> int:
	# rot r rotates local sides counter-clockwise; SIDES are in world order
	# N, E, S, W which corresponds to a clockwise sequence seen from above.
	match fixture.rot:
		1: return 3
		2: return 2
		3: return 1
	return 0


func seat_world_dir(side: int) -> Vector2i:
	return SIDES[side]


func chair_cell(side: int) -> Vector2i:
	return fixture.cell + SIDES[side]


## Returns the sides that have a chair facing this table.
func seated_sides() -> Array[int]:
	var out: Array[int] = []
	var g := world().grid
	for i in 4:
		var c := g.fixture_at(chair_cell(i))
		if c and c.def_id == &"chair" and c.front_cell() == fixture.cell and not c.lifted:
			if not g.wall_between(fixture.cell, chair_cell(i)):
				out.push_back(i)
	return out


func has_dirty_dishes() -> bool:
	for s in fixture.slots:
		if s.item is DishItem and (s.item as DishItem).dirty:
			return true
	return false


func has_items() -> bool:
	for s in fixture.slots:
		if s.item:
			return true
	return false


func group() -> CustomerGroup:
	var w := world()
	if w == null or w.customers == null:
		return null
	return w.customers.group_at_table(fixture)


func is_clean() -> bool:
	return not messy and not has_items()


# -----------------------------------------------------------------------------
# Interaction
# -----------------------------------------------------------------------------

## The seated group reduced to what interaction hints need. Groups only exist
## on the server, so this is replicated in the table state for clients.
func _group_view() -> Dictionary:
	if not Net.is_authority():
		return _view
	var g := group()
	if g == null:
		return {}
	var want := []
	if g.state_waiting_food():
		for m in g.members:
			for o in m.orders:
				if not o.get("served", false):
					want.push_back(String(o["recipe"]))
	return {"o": g.can_take_order(), "w": g.state_waiting_food(), "l": g.is_leaving(), "s": g.status_text(), "r": want}


func _wants(view: Dictionary, d: DishItem) -> bool:
	if Net.is_authority():
		var g := group()
		return g != null and g.find_member_for(d, fixture) != null
	for rid in view.get("r", []):
		var r := Content.recipe(StringName(rid))
		if r and RecipeManager.satisfies(r, d):
			return true
	return false


func server_tick(_delta: float) -> void:
	# Re-send the table when its group's visible state changes.
	if not Net.is_online():
		return
	var v := _group_view()
	if v != _view:
		_view = v
		fixture.mark_dirty()


func query(actor: Node, verb: int) -> Dictionary:
	var held: Item = actor.held()
	var gv := _group_view()
	var seated := not gv.is_empty()
	if verb == GameConst.Verb.USE:
		if gv.get("o", false):
			return {"label": "Take order", "anim": CharacterRig.Anim.THINK}
		if messy and (not seated or gv.get("l", false)):
			return {"label": "Wipe table", "hold": true, "anim": CharacterRig.Anim.WIPE, "progress": wipe / 1.2}
		return {}
	# GRAB
	if held is DishItem:
		var d := held as DishItem
		if d.dirty:
			if can_clear_into(d):
				return {"label": "Clear dishes"}
			return {}
		if not d.contents.is_empty() or d.is_mug():
			if seated and _wants(gv, d):
				var r := d.recipe()
				return {"label": "Serve %s" % (r.display_name if r else d.display_name())}
			if gv.get("w", false):
				return {"label": "Nobody here ordered that", "blocked": true}
		return {}
	if held == null and has_dirty_dishes():
		return {"label": "Clear dishes"}
	return {}


func perform(actor: Node, verb: int, delta: float) -> bool:
	var held: Item = actor.held()
	var g := group()
	if verb == GameConst.Verb.USE:
		if g and g.can_take_order():
			g.take_order(actor)
			return true
		if messy and (g == null or g.is_leaving()):
			wipe += delta
			if wipe >= 1.2:
				wipe = 0.0
				messy = false
				Audio.play_at(&"mop_loop", fixture.global_position, -6.0, 1.4)
				world().fx.sparkle(fixture.global_position + Vector3(0, 0.9, 0), Color(1, 1, 1))
				fixture.mark_dirty()
			return true
		return false
	if held is DishItem:
		var d := held as DishItem
		if d.dirty:
			return _clear_into(actor, d)
		if g:
			return g.serve(actor, d, fixture)
		return false
	if held == null and has_dirty_dishes():
		return _clear_into(actor, null)
	return false


## True if at least one dirty dish here fits onto `pile` (null = empty hands).
func can_clear_into(pile: DishItem) -> bool:
	for s in fixture.slots:
		if s.item is DishItem and (s.item as DishItem).dirty:
			if pile == null or pile.count() + s.item.count() <= pile.max_stack():
				return true
	return false


func _clear_into(actor: Node, pile: DishItem) -> bool:
	var took := false
	for s in fixture.slots:
		if s.item is DishItem and (s.item as DishItem).dirty:
			var d := s.item as DishItem
			if pile == null:
				pile = s.take() as DishItem
				actor.hold(pile)
				took = true
			elif pile.count() + d.count() <= pile.max_stack():
				s.take()
				pile.plates += d.plates
				pile.mugs += d.mugs
				world().despawn(d)
				took = true
	if took and pile:
		pile.rebuild_visual()
		pile.mark_dirty()
		Audio.play_at(&"dish_stack", fixture.global_position)
		fixture.mark_dirty()
	return took


func make_messy() -> void:
	messy = true
	fixture.mark_dirty()


func _process(_delta: float) -> void:
	if fixture == null:
		return
	if messy and _crumbs == null:
		_crumbs = Models.instance(&"crumbs")
		_crumbs.position = Vector3(0, 0.725, 0)
		_crumbs.scale = Vector3(0.9, 1, 0.9)
		fixture.add_child(_crumbs)
	elif not messy and _crumbs:
		_crumbs.queue_free()
		_crumbs = null
	if _number_label:
		_number_label.text = str(number) if number > 0 else ""


func status_text() -> String:
	var gv := _group_view()
	if not gv.is_empty():
		return String(gv.get("s", ""))
	if messy:
		return "Needs wiping"
	if has_dirty_dishes():
		return "Dirty dishes"
	return "Table %d · %d seats" % [number, seated_sides().size()]


func on_placed() -> void:
	if world() and world().customers:
		world().customers.mark_tables_dirty()


func on_lifted() -> void:
	if world() and world().customers:
		world().customers.mark_tables_dirty()


func get_state() -> Dictionary:
	var d := {"n": number}
	if messy:
		d["m"] = true
	if not _view.is_empty():
		d["g"] = _view
	return d


func set_state(d: Dictionary) -> void:
	number = d.get("n", number)
	messy = d.get("m", false)
	if not Net.is_authority():
		_view = d.get("g", {})
