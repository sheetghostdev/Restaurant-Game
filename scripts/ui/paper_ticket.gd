class_name PaperTicket
extends PanelContainer
## One table's order, drawn as a slip of paper from an order pad: a strip of
## tape in the table's colour, the table's name, and for every dish a picture
## of exactly what to make plus its ingredients. Extras the guest didn't ask
## for are shown faded and crossed out, so "no tomato" is obvious.

const W := 252.0
const ICON := 58.0
const CHIP := 36.0
const TEETH := 9.0          ## torn bottom edge
const PAPER := Color("fbf7ea")
const RULE := Color("e7dfcb")

var table := 0
var _bar: ProgressBar
var _fill: StyleBoxFlat
var _pulse: Tween


static func make(e: Dictionary) -> PaperTicket:
	var t := PaperTicket.new()
	t._build(e)
	return t


func _build(e: Dictionary) -> void:
	table = int(e["table"])
	custom_minimum_size = Vector2(W, 0)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 16
	sb.content_margin_bottom = 12 + TEETH
	add_theme_stylebox_override("panel", sb)
	# A little tilt, the same for a table every time
	rotation = deg_to_rad(float((table * 37) % 7 - 3) * 0.55)
	resized.connect(func(): pivot_offset = Vector2(size.x * 0.5, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	# Header: colour swatch + "RED TABLE"
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(_Swatch.new(SeatingTable.color_of(table)))
	var title_text := SeatingTable.name_of(table).to_upper() + " TABLE" if table > 0 else "TAKEAWAY"
	var hl := UITheme.label(title_text, 22, "display")
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(hl)
	v.add_child(head)
	v.add_child(_Rule.new())
	var dishes: Dictionary = e["dishes"]
	for code in dishes:
		v.add_child(_dish_row(String(code), int(dishes[code])))
	# Patience
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 12)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = RULE
	bg.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override("background", bg)
	_fill = StyleBoxFlat.new()
	_fill.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override("fill", _fill)
	v.add_child(_bar)


func _dish_row(code: String, count: int) -> Control:
	var o := RecipeManager.parse_code(code)
	var r := Content.recipe(o["recipe"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var tile := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color("dccbad")
	tsb.set_corner_radius_all(10)
	tile.add_theme_stylebox_override("panel", tsb)
	var tr := TextureRect.new()
	tr.texture = IconRenderer.get_icon("dish:%s" % code)
	tr.custom_minimum_size = Vector2(ICON, ICON)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.add_child(tr)
	row.add_child(tile)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := HBoxContainer.new()
	var nl := UITheme.label(r.ticket_name() if r else code, 19, "bold")
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	title.add_child(nl)
	if count > 1:
		title.add_child(UITheme.label("×%d" % count, 20, "display", Pal.UI_BAD))
	col.add_child(title)
	# Ingredients: everything that goes in, extras not wanted crossed out
	if r and (r.required.size() + r.optional.size() > 1):
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 3)
		var wanted: Array = o["extras"]
		for id in r.required:
			chips.add_child(_chip(id, true))
		for id in r.optional:
			chips.add_child(_chip(id, wanted.has(id)))
		col.add_child(chips)
	row.add_child(col)
	return row


func _chip(id: StringName, included: bool) -> Control:
	var c := _Chip.new()
	c.custom_minimum_size = Vector2(CHIP, CHIP)
	c.texture = IconRenderer.get_icon("cooked:%s" % id)
	c.crossed = not included
	c.tooltip_text = Content.display_name(id)
	return c


func set_patience(p: float) -> void:
	_bar.value = p
	_fill.bg_color = Pal.UI_GOOD if p > 0.5 else (Pal.UI_WARN if p > 0.25 else Pal.UI_BAD)
	if p < 0.25 and _pulse == null:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "modulate", Color(1, 0.74, 0.72), 0.35)
		_pulse.tween_property(self, "modulate", Color.WHITE, 0.35)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h - TEETH)])
	# Torn bottom edge: zig-zag teeth
	var n := int(w / (TEETH * 1.6))
	for i in range(n, -1, -1):
		var x := w * float(i) / n
		pts.push_back(Vector2(x, h - (0.0 if i % 2 == 0 else TEETH)))
	pts.push_back(Vector2(0, h - TEETH))
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.push_back(p + Vector2(3, 4))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.22))
	draw_colored_polygon(pts, PAPER)
	# Faint ruled lines, like an order pad
	var y := 52.0
	while y < h - TEETH - 8:
		draw_line(Vector2(8, y), Vector2(w - 8, y), RULE, 1.0)
		y += 26.0
	# Tape in the table's colour, holding the slip to the rail
	var tc := SeatingTable.color_of(table)
	var tape := Rect2(w * 0.5 - 30, -9, 60, 20)
	draw_set_transform(tape.get_center(), deg_to_rad(-4), Vector2.ONE)
	draw_rect(Rect2(-tape.size * 0.5, tape.size), Color(tc.r, tc.g, tc.b, 0.88))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## Round colour swatch next to the table name.
class _Swatch extends Control:
	var col: Color

	func _init(c: Color) -> void:
		col = c
		custom_minimum_size = Vector2(24, 24)

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 11.0, Pal.UI_INK)
		draw_circle(c, 9.0, col)


## Dashed rule under the header.
class _Rule extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 4)

	func _draw() -> void:
		var x := 0.0
		while x < size.x:
			draw_line(Vector2(x, 2), Vector2(minf(x + 7, size.x), 2), Color("c9bea6"), 2.0)
			x += 12.0


## Ingredient picture; crossed out (and faded) when the guest doesn't want it.
class _Chip extends Control:
	var texture: Texture2D
	var crossed := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("efe5cf") if not crossed else Color("f3eee2"))
		if texture:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.3 if crossed else 1.0))
		if crossed:
			draw_line(Vector2(3, 3), size - Vector2(3, 3), Pal.UI_BAD, 3.0)
			draw_line(Vector2(3, size.y - 3), Vector2(size.x - 3, 3), Pal.UI_BAD, 3.0)
