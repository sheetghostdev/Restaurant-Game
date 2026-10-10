class_name PaperUI
extends Control
## The Morning Paper (see MorningPaper): from day 2 a newspaper lands every
## morning and the crew picks one of its three stories before prep starts.
## Any player can pick, with the mouse, the keyboard or a gamepad.

var hud: HUD
var _card: PanelContainer
var _body: VBoxContainer
var _built_for := ""
var _first: Button

const NEWSPRINT := Color("efe6d2")
const KIND_COLORS := {
	"Booking": Pal.UI_ACCENT, "News": Pal.UI_BAD, "Weather": Color("3d6fa8"),
	"Trend": Pal.UI_WARN, "Deal": Pal.UI_MONEY, "Local": Pal.UI_INK_SOFT,
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.12, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = PanelContainer.new()
	var sb := UITheme.card(NEWSPRINT, Pal.UI_INK, 4, 3)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	_card.add_theme_stylebox_override("panel", sb)
	center.add_child(_card)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_card.add_child(_body)


func _process(_delta: float) -> void:
	if hud == null or hud.world == null or hud.world.day == null:
		return
	var d := hud.world.day
	var want := d.paper_pending() and not (hud.results.visible or hud.catalog.visible or hud.pause_menu.visible or hud.recipe_book.visible)
	if want != visible:
		visible = want
		if want:
			_rebuild()
			_card.pivot_offset = _card.size * 0.5
			_card.scale = Vector2(0.92, 0.92)
			_card.rotation = -0.04
			var tw := create_tween().set_parallel()
			tw.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_card, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Audio.play_ui(&"ui_confirm")
		else:
			hud._refresh_forecast()
	if not visible:
		return
	if _key() != _built_for:
		_rebuild()
	# Keep a story selected so a gamepad or the keyboard can always pick.
	var f := get_viewport().gui_get_focus_owner()
	if _first and (f == null or not is_ancestor_of(f)):
		_first.grab_focus()


func _key() -> String:
	var d := hud.world.day
	return "%d|%s" % [d.day, ",".join(d.paper.get("offers", []).map(func(h): return String(h["id"])))]


func _rebuild() -> void:
	_built_for = _key()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var w := hud.world
	var d := w.day
	var top := HBoxContainer.new()
	top.add_child(UITheme.label("No. %d" % d.day, 15, "bold", Pal.UI_INK_SOFT))
	top.add_child(_spacer())
	var place := w.location.display_name if w.location else ""
	var ed := UITheme.label(("%s edition" % place) if place != "" else "Morning edition", 15, "bold", Pal.UI_INK_SOFT)
	top.add_child(ed)
	top.add_child(_spacer())
	top.add_child(UITheme.label("Free to the crew", 15, "bold", Pal.UI_INK_SOFT))
	_body.add_child(top)
	_body.add_child(_rule(3))
	var mast := UITheme.heading("The Morning Paper", 60)
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(mast)
	var rules := VBoxContainer.new()
	rules.add_theme_constant_override("separation", 3)
	rules.add_child(_rule(3))
	rules.add_child(_rule(1))
	_body.add_child(rules)
	var sub := UITheme.label("Pick today's story: it changes how the day goes. The prep clock starts once you've chosen.", 17, "regular", Pal.UI_INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(sub)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	_body.add_child(cols)
	_first = null
	var offers: Array = d.paper.get("offers", [])
	for i in offers.size():
		if i > 0:
			cols.add_child(_vrule())
		cols.add_child(_story(i, offers[i]))
	_body.add_child(_rule(1))
	var bin := UITheme.button("Bin the paper: just an ordinary day", func(): Net.request("headline", [-1]), 16)
	bin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(bin)


func _story(i: int, h: Dictionary) -> Control:
	var kind := String(h.get("kind", ""))
	var tint: Color = KIND_COLORS.get(kind, Pal.UI_INK)
	var col := PanelContainer.new()
	col.custom_minimum_size = Vector2(300, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(NEWSPRINT, 0.0)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3)
	sb.border_color = Color(tint, 0.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 12)
	var hi := sb.duplicate() as StyleBoxFlat
	hi.bg_color = Color("fbf5e4")
	hi.border_color = tint
	col.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	col.add_child(v)
	v.add_child(UITheme.label(kind.to_upper(), 15, "bold", tint))
	var art := PaperArt.new()
	art.id = String(h.get("id", ""))
	art.tint = tint
	art.icon_key = String(h.get("icon", ""))
	art.custom_minimum_size = Vector2(0, 118)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(art)
	var title := UITheme.heading(String(h.get("title", "")), 25)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(276, 0)
	v.add_child(title)
	var text := UITheme.label(String(h.get("text", "")), 17, "regular", Pal.UI_INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(276, 0)
	v.add_child(text)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	var btn := UITheme.button("Run this story", func(): Net.request("headline", [i]), 19)
	v.add_child(btn)
	btn.focus_entered.connect(func(): col.add_theme_stylebox_override("panel", hi))
	btn.focus_exited.connect(func(): col.add_theme_stylebox_override("panel", sb))
	# The whole column is the button for the mouse.
	col.mouse_entered.connect(func(): btn.grab_focus())
	col.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			btn.pressed.emit())
	if _first == null:
		_first = btn
	return col


func _rule(px: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = Pal.UI_INK
	r.custom_minimum_size = Vector2(0, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _vrule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(Pal.UI_INK, 0.5)
	r.custom_minimum_size = Vector2(1, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## A newsprint "photo" for a story: halftone dots and a simple ink drawing.
class PaperArt extends Control:
	var id := ""
	var tint := Pal.UI_INK
	var icon_key := ""
	var _tex: Texture2D
	const INK := Color("2e2622")
	const PAPER := Color("ddd2bb")

	func _ready() -> void:
		if icon_key != "":
			_tex = IconRenderer.get_icon(icon_key)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, PAPER, true)
		var step := 7.0
		var y := step * 0.5
		while y < size.y:
			var x := step * 0.5 + (step * 0.5 if int(y / step) % 2 == 1 else 0.0)
			while x < size.x:
				draw_circle(Vector2(x, y), 0.6 + 1.4 * y / size.y, Color(INK, 0.13))
				x += step
			y += step
		var c := size * 0.5
		match id:
			"coach": _bus(c)
			"party": _cake(c)
			"critic": _critic(c)
			"famous": _star(c, 42.0, Pal.UI_STAR)
			"rain": _rain(c)
			"heat": _sun(c)
			"craze": _plate(c)
			"clearance": _tag(c)
			"surplus": _crates(c)
			"ad": _megaphone(c)
			_: _star(c, 30.0, tint)
		draw_rect(r, INK, false, 2.0)

	func _bus(c: Vector2) -> void:
		draw_line(Vector2(0, c.y + 38), Vector2(size.x, c.y + 38), Color(INK, 0.5), 2.0)
		var body := Rect2(c + Vector2(-78, -34), Vector2(156, 62))
		draw_rect(body, Color("f4ead6"), true)
		draw_rect(Rect2(body.position + Vector2(0, 40), Vector2(body.size.x, 9)), tint, true)
		draw_rect(body, INK, false, 3.0)
		for k in 5:
			var wr := Rect2(body.position + Vector2(10 + k * 28, 9), Vector2(20, 20))
			draw_rect(wr, Color("9fc3d6"), true)
			draw_rect(wr, INK, false, 2.0)
		for wx in [-46.0, 46.0]:
			draw_circle(c + Vector2(wx, 30), 12.0, INK)
			draw_circle(c + Vector2(wx, 30), 5.0, Color("b9b0a0"))

	func _cake(c: Vector2) -> void:
		var base := Rect2(c + Vector2(-56, 4), Vector2(112, 38))
		var top := Rect2(c + Vector2(-36, -24), Vector2(72, 30))
		for t in [base, top]:
			draw_rect(t, Color("f6d7c3"), true)
			draw_rect(Rect2(t.position, Vector2(t.size.x, 9)), tint, true)
			draw_rect(t, INK, false, 3.0)
		for k in 3:
			var x := c.x - 22 + k * 22
			draw_rect(Rect2(Vector2(x - 3, c.y - 44), Vector2(6, 20)), Color("f2f2f2"), true)
			draw_rect(Rect2(Vector2(x - 3, c.y - 44), Vector2(6, 20)), INK, false, 1.5)
			draw_circle(Vector2(x, c.y - 50), 5.0, Pal.UI_WARN)

	func _critic(c: Vector2) -> void:
		_ellipse(c + Vector2(-14, 26), Vector2(62, 16), Color("f4f0e8"))
		_ellipse(c + Vector2(-14, 24), Vector2(36, 9), Color("c97a4a"))
		draw_circle(c + Vector2(24, -12), 30.0, Color(1, 1, 1, 0.35))
		draw_arc(c + Vector2(24, -12), 30.0, 0, TAU, 36, INK, 6.0)
		draw_line(c + Vector2(45, 9), c + Vector2(76, 40), INK, 10.0)
		for k in 3:
			_star(c + Vector2(-70 + k * 22, -36), 9.0, Pal.UI_STAR)

	func _star(c: Vector2, rad: float, col: Color) -> void:
		if rad > 30.0:
			for k in 12:
				var a := TAU * k / 12.0
				draw_line(c + Vector2.from_angle(a) * (rad + 6), c + Vector2.from_angle(a) * (rad + 18), Color(INK, 0.6), 3.0)
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2.0 + TAU * k / 10.0
			pts.push_back(c + Vector2.from_angle(a) * (rad if k % 2 == 0 else rad * 0.45))
		draw_colored_polygon(pts, col)
		pts.push_back(pts[0])
		draw_polyline(pts, INK, 2.5 if rad > 15 else 1.5)

	func _rain(c: Vector2) -> void:
		for k in 9:
			var x := c.x - 70 + k * 18
			draw_line(Vector2(x, c.y + 6), Vector2(x - 8, c.y + 40), tint, 3.0)
		var cl := Color("e9e4da")
		for p in [Vector2(-40, -10), Vector2(-8, -26), Vector2(30, -12), Vector2(56, 0)]:
			draw_circle(c + p, 26.0, INK)
		draw_rect(Rect2(c + Vector2(-60, -6), Vector2(130, 24)), INK, true)
		for p in [Vector2(-40, -10), Vector2(-8, -26), Vector2(30, -12), Vector2(56, 0)]:
			draw_circle(c + p, 23.0, cl)
		draw_rect(Rect2(c + Vector2(-57, -4), Vector2(124, 19)), cl, true)

	func _sun(c: Vector2) -> void:
		var s := c + Vector2(0, -6)
		for k in 12:
			var a := TAU * k / 12.0
			draw_line(s + Vector2.from_angle(a) * 36, s + Vector2.from_angle(a) * 52, INK, 4.0)
		draw_circle(s, 30.0, Pal.UI_WARN)
		draw_arc(s, 30.0, 0, TAU, 32, INK, 3.0)
		for k in 3:
			var y := c.y + 46
			var pts := PackedVector2Array()
			for j in 9:
				pts.push_back(Vector2(c.x - 90 + k * 64 + j * 6, y + sin(j * 1.2) * 3.0))
			draw_polyline(pts, Color(INK, 0.6), 2.0)

	func _plate(c: Vector2) -> void:
		_ellipse(c + Vector2(0, 8), Vector2(70, 34), Color("f4f0e8"))
		_ellipse(c + Vector2(0, 8), Vector2(46, 22), Color("e6dfd2"))
		if _tex:
			draw_texture_rect(_tex, Rect2(c - Vector2(52, 58), Vector2(104, 104)), false)
		else:
			_heart(c + Vector2(0, 2), 18.0)
		for p in [Vector2(-92, -30), Vector2(88, -24)]:
			_heart(c + p, 10.0)

	func _heart(c: Vector2, s: float) -> void:
		draw_circle(c + Vector2(-s * 0.5, -s * 0.2), s * 0.55, Pal.UI_BAD)
		draw_circle(c + Vector2(s * 0.5, -s * 0.2), s * 0.55, Pal.UI_BAD)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.02, 0), c + Vector2(s * 1.02, 0), c + Vector2(0, s * 1.1)]), Pal.UI_BAD)

	func _tag(c: Vector2) -> void:
		var pts := PackedVector2Array([c + Vector2(-70, -30), c + Vector2(40, -30), c + Vector2(72, 0), c + Vector2(40, 30), c + Vector2(-70, 30)])
		draw_colored_polygon(pts, Color("f4ead6"))
		pts.push_back(pts[0])
		draw_polyline(pts, INK, 3.0)
		draw_circle(c + Vector2(44, 0), 6.0, PAPER)
		draw_arc(c + Vector2(44, 0), 6.0, 0, TAU, 16, INK, 2.0)
		draw_line(c + Vector2(50, 0), c + Vector2(96, -36), INK, 2.0)
		var f := UITheme.font("display")
		draw_string(f, c + Vector2(-64, 13), "-30%", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, tint)

	func _crates(c: Vector2) -> void:
		for k in 2:
			var r := Rect2(c + Vector2(-78 + k * 82, -26), Vector2(74, 56))
			draw_rect(r, Color("c79a5b"), true)
			for j in 3:
				draw_line(r.position + Vector2(0, 14 + j * 14), r.position + Vector2(r.size.x, 14 + j * 14), Color(INK, 0.45), 2.0)
			draw_rect(r, INK, false, 3.0)
			if _tex:
				draw_texture_rect(_tex, Rect2(r.get_center() - Vector2(26, 26), Vector2(52, 52)), false)

	func _megaphone(c: Vector2) -> void:
		var pts := PackedVector2Array([c + Vector2(-50, -12), c + Vector2(20, -40), c + Vector2(20, 40), c + Vector2(-50, 12)])
		draw_colored_polygon(pts, tint)
		pts.push_back(pts[0])
		draw_polyline(pts, INK, 3.0)
		draw_rect(Rect2(c + Vector2(-66, -12), Vector2(16, 24)), INK, true)
		draw_rect(Rect2(c + Vector2(-40, 10), Vector2(10, 26)), INK, true)
		for k in 3:
			draw_arc(c + Vector2(24, 0), 20.0 + k * 14, -0.7, 0.7, 12, INK, 3.0)

	func _ellipse(c: Vector2, radii: Vector2, col: Color) -> void:
		draw_set_transform(c, 0.0, Vector2(1.0, radii.y / radii.x))
		draw_circle(Vector2.ZERO, radii.x + 2.0, INK)
		draw_circle(Vector2.ZERO, radii.x, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
