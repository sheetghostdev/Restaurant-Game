class_name MenuBoard
extends FixtureComponent
## The chalkboard menu. USE opens the Menu page, where ingredients can be
## crossed off when they run out: guests stop ordering dishes that need them
## (and stop asking for them as extras), at the cost of some disappointment.
## The board itself lists the ingredients in chalk, struck ones in red.

const SLATE_Z := -0.218
var _chalk: Node3D
var _key := "~"


func _ready() -> void:
	_chalk = Node3D.new()
	_chalk.name = "Chalk"
	fixture.add_child.call_deferred(_chalk)


func query(_actor: Node, verb: int) -> Dictionary:
	if verb == GameConst.Verb.USE:
		return {"label": "Change the menu"}
	return {}


func perform(actor: Node, verb: int, _delta: float) -> bool:
	if verb != GameConst.Verb.USE:
		return false
	Net.open_catalog_for(actor, "menu")
	return true


func status_text() -> String:
	var w := world()
	if w == null:
		return ""
	var n := w.orders.struck.size()
	return "Everything's on" if n == 0 else "%d crossed off" % n


func _process(_delta: float) -> void:
	var w := world()
	if w == null or w.format == null or _chalk == null or not _chalk.is_inside_tree():
		return
	var key := str(w.orders.struck.keys())
	if key == _key:
		return
	_key = key
	for c in _chalk.get_children():
		c.queue_free()
	_chalk.add_child(_text("MENU", Vector3(0, 1.56, SLATE_Z), 46, Color(0.97, 0.95, 0.88)))
	var y := 1.4
	for ing in Content.menu_ingredients(w.format):
		var off := w.orders.is_struck(ing)
		var col := Color(0.95, 0.94, 0.88, 0.45 if off else 0.95)
		var t := _text(Content.display_name(ing), Vector3(-0.36, y, SLATE_Z), 30, col)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_chalk.add_child(t)
		if off:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.66, 0.025, 0.004)
			bar.mesh = bm
			bar.material_override = Models.mat_unshaded(Color("ff5a4a"))
			bar.position = Vector3(-0.03, y, SLATE_Z + 0.004)
			bar.rotation.z = 0.06
			_chalk.add_child(bar)
		y -= 0.13


func _text(s: String, pos: Vector3, size: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = s
	l.font = load("res://art/fonts/Rubik-Bold.ttf")
	l.font_size = size
	l.pixel_size = 0.0034
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.double_sided = false
	return l
