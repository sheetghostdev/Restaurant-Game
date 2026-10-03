class_name MarketStall
extends FixtureComponent
## A stall on a station platform selling one kind of crate. GRAB with empty
## hands to buy a full crate (paid on the spot). Stalls pack up when the
## train leaves.

var supply_id: StringName
var price := 10.0
var stock := 2
var tag := ""          ## "deal": this stop's specialty
var _goods: Node3D
var _sign: Label3D
var _shown := ""


func _supply() -> SupplyDef:
	return Content.supply(supply_id)


func query(actor: Node, verb: int) -> Dictionary:
	if verb != GameConst.Verb.GRAB or actor.held() != null:
		return {}
	var s := _supply()
	if s == null:
		return {}
	if stock <= 0:
		return {"label": "Sold out", "blocked": true}
	var w := world()
	if w and not w.economy.can_afford(price):
		return {"label": "Can't afford %s" % GameConst.money(price), "blocked": true}
	return {"label": "Buy %s · %s" % [s.display_name, GameConst.money(price)]}


func perform(actor: Node, verb: int, _delta: float) -> bool:
	if query(actor, verb).is_empty() or query(actor, verb).get("blocked", false):
		return false
	var s := _supply()
	if not world().economy.spend(price, "Market: %s" % s.display_name):
		return false
	var crate := world().spawn_crate(supply_id, -1, {"none": true})
	actor.hold(crate)
	stock -= 1
	Audio.play_at(&"cash_register", fixture.global_position, -4.0, 1.2)
	fixture.mark_dirty()
	return true


func status_text() -> String:
	var s := _supply()
	if s == null:
		return ""
	return "%s · %s · %d left%s" % [s.display_name, GameConst.money(price), stock, " · DEAL!" if tag == "deal" else ""]


func _process(_delta: float) -> void:
	if fixture == null or not fixture.is_inside_tree():
		return
	var key := "%s|%d|%s|%s" % [supply_id, stock, price, tag]
	if key == _shown:
		return
	_shown = key
	_refresh()


## The goods on the counter (fewer as they sell) and the price board.
func _refresh() -> void:
	if _goods:
		_goods.queue_free()
	_goods = Node3D.new()
	fixture.add_child(_goods)
	var s := _supply()
	if s == null:
		return
	var d := Content.item(s.item_id)
	var n := mini(stock, 3) * 2
	for i in n:
		var m := Models.instance(d.model if d else &"crate")
		m.position = Vector3(-0.27 + (i % 3) * 0.27, 0.9, 0.05 + (i / 3) * 0.2)
		m.rotation.y = i * 1.3
		m.scale = Vector3.ONE * 0.9
		_goods.add_child(m)
	if _sign == null:
		_sign = Label3D.new()
		_sign.font = load("res://art/fonts/AlfaSlabOne-Regular.ttf")
		_sign.font_size = 44
		_sign.pixel_size = 0.0042
		_sign.outline_size = 10
		_sign.outline_modulate = Pal.UI_PAPER
		_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_sign.no_depth_test = false
		_sign.position = Vector3(0, 2.45, 0.1)
		fixture.add_child(_sign)
	var deal := tag == "deal"
	_sign.text = "%s%s\n%s" % ["DEAL! " if deal else "", s.display_name, ("SOLD OUT" if stock <= 0 else GameConst.money(price))]
	_sign.modulate = Pal.UI_BAD if deal else Pal.UI_INK


func get_state() -> Dictionary:
	return {"s": String(supply_id), "p": price, "n": stock, "tag": tag}


func set_state(d: Dictionary) -> void:
	supply_id = StringName(d.get("s", supply_id))
	price = float(d.get("p", price))
	stock = int(d.get("n", stock))
	tag = String(d.get("tag", tag))
