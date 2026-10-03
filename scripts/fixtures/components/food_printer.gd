class_name FoodPrinter
extends FixtureComponent
## Prints ingredients in orbit: USE picks what to print, then it prints one
## portion at a time (charged when it's done) until a few are waiting in the
## tray. GRAB with empty hands takes one.

const PRINT_TIME := 5.0
const MAX_READY := 3
const MARKUP := 1.3

var selected: StringName
var stock := 0
var progress := 0.0
var _tray: Node3D
var _shown := ""
var _out_of_credits := false


## Everything the menu uses can be printed (refills too: beans, syrup, kegs).
func choices() -> Array[StringName]:
	var w := world()
	if w == null or w.format == null:
		return []
	return Content.menu_ingredients(w.format)


func unit_price(id: StringName) -> float:
	var s := Content.supply_for_item(id)
	if s == null:
		return 2.0
	return snappedf(s.price / maxf(s.quantity, 1) * MARKUP, 0.05)


func _ensure() -> void:
	var c := choices()
	if selected == &"" or not c.has(selected):
		# Start with something the planters can't grow.
		selected = &""
		for id in c:
			if Content.item(id) and Content.item(id).grow_seconds <= 0.0:
				selected = id
				break
		if selected == &"" and not c.is_empty():
			selected = c[0]


func query(actor: Node, verb: int) -> Dictionary:
	if actor.held() != null:
		return {}
	_ensure()
	if verb == GameConst.Verb.GRAB and selected != &"":
		if stock > 0:
			return {"label": "Take %s" % Content.display_name(selected).to_lower()}
		return {"label": "Printing…", "blocked": true}
	if verb == GameConst.Verb.USE:
		var c := choices()
		if c.size() > 1:
			var nxt := c[(c.find(selected) + 1) % c.size()]
			return {"label": "Print %s (%s)" % [Content.display_name(nxt).to_lower(), GameConst.money(unit_price(nxt))]}
	return {}


func perform(actor: Node, verb: int, _delta: float) -> bool:
	var q := query(actor, verb)
	if q.is_empty() or q.get("blocked", false):
		return false
	if verb == GameConst.Verb.GRAB:
		stock -= 1
		actor.hold(world().spawn_item(selected))
		Audio.play_at(&"crate_take", fixture.global_position, -2.0, 1.4)
	else:
		var c := choices()
		selected = c[(c.find(selected) + 1) % c.size()]
		# What's already printed can't change; only new prints switch.
		stock = 0
		progress = 0.0
		Audio.play_at(&"ui_confirm", fixture.global_position, -4.0)
	fixture.mark_dirty()
	return true


func server_tick(delta: float) -> void:
	_ensure()
	if selected == &"" or stock >= MAX_READY or not fixture.is_working():
		return
	var price := unit_price(selected)
	if not world().economy.can_afford(price):
		if not _out_of_credits:
			_out_of_credits = true
			fixture.mark_dirty()
		return
	_out_of_credits = false
	progress += delta / PRINT_TIME
	if progress >= 1.0:
		progress = 0.0
		stock += 1
		world().economy.charge(price, "Printed %s" % Content.display_name(selected))
		Audio.play_at(&"ding", fixture.global_position, -10.0, 1.6)
		fixture.mark_dirty()


func is_printing() -> bool:
	return selected != &"" and stock < MAX_READY and not _out_of_credits and fixture.is_working()


func status_text() -> String:
	_ensure()
	if selected == &"":
		return ""
	var n := Content.display_name(selected)
	if _out_of_credits:
		return "%s · out of credits!" % n
	return "%s · %s each · %d ready" % [n, GameConst.money(unit_price(selected)), stock]


func _process(_delta: float) -> void:
	if fixture == null or not fixture.is_inside_tree():
		return
	Audio.loop(fixture, &"conveyor_loop", is_printing() and Net.is_authority(), -12.0)
	var key := "%s|%d" % [selected, stock]
	if key == _shown:
		return
	_shown = key
	if _tray:
		_tray.queue_free()
	_tray = Node3D.new()
	fixture.add_child(_tray)
	if selected == &"":
		return
	var d := Content.item(selected)
	for i in stock:
		var m := Models.instance(d.model)
		m.position = Vector3(-0.2 + i * 0.2, 0.86, 0.26)
		m.scale = Vector3.ONE * 0.75
		_tray.add_child(m)


func get_state() -> Dictionary:
	return {"s": String(selected), "r": stock, "o": _out_of_credits}


func set_state(d: Dictionary) -> void:
	selected = StringName(d.get("s", String(selected)))
	stock = int(d.get("r", stock))
	_out_of_credits = bool(d.get("o", false))
