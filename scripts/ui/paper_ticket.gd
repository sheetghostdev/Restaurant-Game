class_name PaperTicket
extends PanelContainer
## One table's order, drawn as a small slip of paper from an order pad: tape
## in the table's colour, the table's name, and for every dish a picture of
## exactly what to make. Optional extras sit beside the picture: shown when
## wanted, crossed out when not, so "no tomato" is obvious.

const ICON := 42.0         ## dish picture
const CHIP := 19.0         ## extra ingredient, beside the picture
const TILE_GAP := 8.0
const TEETH := 6.0          ## torn bottom edge
const PAPER := Color("fbf7ea")
const RULE := Color("e7dfcb")
## Every ticket fits in this many pixels of height: the camera keeps the
## restaurant below the band, so tickets never cover anything.
const BAND := 118.0

var table := 0
var _bar: ProgressBar
var _fill: StyleBoxFlat
var _pulse: Tween


## Width a slip will need for these dishes ({code: count}), before layout.
static func estimate_width(dishes: Dictionary) -> float:
	var w := 18.0
	var n := 0
	for code in dishes:
		var r := Content.recipe(RecipeManager.parse_code(String(code))["recipe"])
		w += ICON + (CHIP + 2.0 if r and not r.optional.is_empty() else 0.0)
		n += 1
	w += TILE_GAP * maxi(n - 1, 0)
	return maxf(w, 84.0)


static func make(e: Dictionary) -> PaperTicket:
	var t := PaperTicket.new()
	t._build(e)
	return t


## Compact slip: tape in the table's colour, "RED", then one small tile per
## dish (its picture, the extras it wants or must not have, its name).
func _build(e: Dictionary) -> void:
	table = int(e["table"])
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 10
	sb.content_margin_bottom = 7 + TEETH
	add_theme_stylebox_override("panel", sb)
	rotation = deg_to_rad(float((table * 37) % 7 - 3) * 0.4)
	resized.connect(func(): pivot_offset = Vector2(size.x * 0.5, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	head.add_child(_Swatch.new(SeatingTable.color_of(table)))
	var hl := UITheme.label(SeatingTable.name_of(table).to_upper() if table > 0 else "TAKEAWAY", 16, "display")
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(hl)
	v.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(TILE_GAP))
	var dishes: Dictionary = e["dishes"]
	for code in dishes:
		row.add_child(_dish_tile(String(code), int(dishes[code])))
	v.add_child(row)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 7)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = RULE
	bg.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", bg)
	_fill = StyleBoxFlat.new()
	_fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", _fill)
	v.add_child(_bar)


func _dish_tile(code: String, count: int) -> Control:
	var o := RecipeManager.parse_code(code)
	var r := Content.recipe(o["recipe"])
	var tile := VBoxContainer.new()
	tile.add_theme_constant_override("separation", 1)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	var pic := _Picture.new()
	pic.texture = IconRenderer.get_icon("dish:%s" % code)
	pic.count = count
	pic.custom_minimum_size = Vector2(ICON, ICON)
	top.add_child(pic)
	# The optional extras: shown if wanted, crossed out if not. (Everything
	# else is in the picture.)
	if r and not r.optional.is_empty():
		var chips := VBoxContainer.new()
		chips.add_theme_constant_override("separation", 2)
		var wanted: Array = o["extras"]
		for id in r.optional:
			chips.add_child(_chip(id, wanted.has(id)))
		top.add_child(chips)
	tile.add_child(top)
	var nl := UITheme.label(r.ticket_name() if r else code, 12, "bold", Pal.UI_INK_SOFT)
	nl.clip_text = true
	nl.custom_minimum_size = Vector2(ICON, 0)
	tile.add_child(nl)
	return tile


func _chip(id: StringName, included: bool) -> Control:
	var c := _Chip.new()
	c.custom_minimum_size = Vector2(CHIP, CHIP)
	c.texture = IconRenderer.get_icon("cooked:%s" % id)
	c.crossed = not included
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
	var y := 33.0
	while y < h - TEETH - 14:
		draw_line(Vector2(6, y), Vector2(w - 6, y), RULE, 1.0)
		y += 20.0
	# Tape in the table's colour, holding the slip to the rail
	var tc := SeatingTable.color_of(table)
	var tape := Rect2(w * 0.5 - 22, -7, 44, 14)
	draw_set_transform(tape.get_center(), deg_to_rad(-4), Vector2.ONE)
	draw_rect(Rect2(-tape.size * 0.5, tape.size), Color(tc.r, tc.g, tc.b, 0.88))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## Round colour swatch next to the table name.
class _Swatch extends Control:
	var col: Color

	func _init(c: Color) -> void:
		col = c
		custom_minimum_size = Vector2(16, 16)

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 7.5, Pal.UI_INK)
		draw_circle(c, 6.0, col)


## Ingredient picture; crossed out (and faded) when the guest doesn't want it.
class _Chip extends Control:
	var texture: Texture2D
	var crossed := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("efe5cf") if not crossed else Color("f3eee2"))
		if texture:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.3 if crossed else 1.0))
		if crossed:
			draw_line(Vector2(2, 2), size - Vector2(2, 2), Pal.UI_BAD, 2.5)
			draw_line(Vector2(2, size.y - 2), Vector2(size.x - 2, 2), Pal.UI_BAD, 2.5)


## The dish picture on a tan tile, with a red "×2" badge for repeats.
class _Picture extends Control:
	var texture: Texture2D
	var count := 1

	func _draw() -> void:
		draw_style_box(_box(), Rect2(Vector2.ZERO, size))
		if texture:
			draw_texture_rect(texture, Rect2(Vector2(1, 1), size - Vector2(2, 2)), false)
		if count > 1:
			var font := UITheme.font("display")
			var c := Vector2(size.x - 7, 7)
			draw_circle(c, 10.0, Pal.UI_BAD)
			draw_string(font, c + Vector2(-8, 5), "×%d" % count, HORIZONTAL_ALIGNMENT_CENTER, 16, 13, Color.WHITE)

	func _box() -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = Color("dccbad")
		b.set_corner_radius_all(7)
		return b
