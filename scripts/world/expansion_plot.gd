class_name ExpansionPlot
extends Entity
## An empty lot next to the restaurant, taped off with a FOR SALE sign. Hold USE
## at the sign during a calm phase to build the expansion.

var _hold := 0.0
const HOLD := 1.2
var _label: Label3D


func get_kind() -> StringName:
	return &"plot"


func expansion() -> ExpansionDef:
	return Content.expansions.get(def_id)


func _ready() -> void:
	add_to_group(&"interactables")
	var e := expansion()
	if e == null:
		return
	# Tape outline + dirt patch (in world space)
	var b := MeshBuilder.new()
	var r := e.rect
	var origin := global_position
	var y := -0.015
	b.block(Vector3(r.get_center().x, y - 0.01, r.get_center().y) - origin, Vector3(r.size.x - 0.1, 0.02, r.size.y - 0.1), Pal.DIRT, 0.0)
	var stripes := 0
	for x in range(r.position.x, r.end.x):
		for side in [r.position.y, r.end.y]:
			var col := Pal.HAZARD if (stripes % 2) == 0 else Pal.CHARCOAL
			b.box(Vector3(x + 0.5, 0.012, side) - origin, Vector3(0.98, 0.02, 0.07), col)
			stripes += 1
	for z in range(r.position.y, r.end.y):
		for side in [r.position.x, r.end.x]:
			var col2 := Pal.HAZARD if (stripes % 2) == 0 else Pal.CHARCOAL
			b.box(Vector3(side, 0.012, z + 0.5) - origin, Vector3(0.07, 0.02, 0.98), col2)
			stripes += 1
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Models.mat_main())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var sign_node := Models.instance(&"for_sale_sign")
	add_child(sign_node)
	for k in 2:
		var cone := Models.instance(&"cone")
		cone.position = Vector3(r.position.x + 0.6 + k * (r.size.x - 1.2), 0, r.get_center().y) - Vector3(origin.x, 0, origin.z)
		add_child(cone)
	_label = Label3D.new()
	_label.font = load("res://art/fonts/Rubik-Bold.ttf")
	_label.font_size = 40
	_label.pixel_size = 0.0038
	_label.modulate = Pal.UI_INK
	_label.outline_size = 0
	_label.position = Vector3(0, 0.95, 0.07)
	_label.text = "%s\n%s" % [e.display_name, GameConst.money(e.price)]
	_label.width = 300
	add_child(_label)


func target_point() -> Vector3:
	return global_position


func display_name() -> String:
	var e := expansion()
	return e.display_name if e else "Lot"


func status_text() -> String:
	var e := expansion()
	return e.description if e else ""


func interact_query(actor: Node, verb: int) -> Dictionary:
	if verb != GameConst.Verb.USE or world == null:
		return {}
	var e := expansion()
	if e == null:
		return {}
	if not world.is_calm():
		return {"label": "Build after closing", "blocked": true}
	return {"label": "Build %s (%s)" % [e.display_name, GameConst.money(e.price)], "hold": true, "progress": _hold / HOLD, "anim": CharacterRig.Anim.REPAIR}


func interact_perform(_actor: Node, verb: int, delta: float) -> bool:
	if verb != GameConst.Verb.USE or not world.is_calm():
		return false
	_hold += delta
	if _hold >= HOLD:
		_hold = 0.0
		world.build.buy_expansion(def_id)
	return true


func _process(delta: float) -> void:
	_hold = maxf(_hold - delta * 0.4, 0.0)
