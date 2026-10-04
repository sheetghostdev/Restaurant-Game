class_name NewGamePanel
extends PanelContainer
## "Open a new restaurant": pick where (Main Street, the train, the space
## station) and what kind of place (diner, coffee shop, pizza parlor, bar),
## name it, and open — offline or hosting for friends.

signal started(setup: Dictionary, host: bool)
signal closed
signal preview_changed(location_id: StringName, format_id: StringName)

var location_id: StringName = &"main_street"
var format_id: StringName = &"diner"
var _loc_cards := {}
var _fmt_cards := {}
var _name: LineEdit
var _name_edited := false
var _status: Label
var _confirm := false


static func make() -> NewGamePanel:
	var p := NewGamePanel.new()
	p.add_theme_stylebox_override("panel", UITheme.card(Pal.UI_PAPER, Pal.UI_INK, 18, 4))
	return p


func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UITheme.heading("Open a New Restaurant", 34))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UITheme.button("Back ✕", func(): closed.emit(), 18))
	v.add_child(head)
	v.add_child(UITheme.label("WHERE?", 18, "bold", Pal.UI_INK_SOFT))
	var locs := HBoxContainer.new()
	locs.add_theme_constant_override("separation", 12)
	v.add_child(locs)
	for l in _sorted(Content.locations, ["main_street", "express", "orbital"]):
		var ld := l as LocationDef
		if not ld.playable:
			continue
		var c := _card(ld.accent, ld.display_name, ld.tagline, _supply_line(ld), Vector2(352, 236), [], ld.description)
		var id: StringName = ld.id
		c.pressed.connect(func(): _pick_location(id))
		locs.add_child(c)
		_loc_cards[id] = c
	v.add_child(UITheme.label("WHAT KIND OF PLACE?", 18, "bold", Pal.UI_INK_SOFT))
	var fmts := HBoxContainer.new()
	fmts.add_theme_constant_override("separation", 12)
	v.add_child(fmts)
	for f in _sorted(Content.formats, ["diner", "coffee_shop", "pizza_parlor", "bar"]):
		var fd := f as RestaurantFormatDef
		if not fd.playable:
			continue
		var hours := "Open %s – %s" % [GameConst.clock_text(fd.open_hour).replace(":00", ""), GameConst.clock_text(fd.close_hour).replace(":00", "")]
		var c2 := _card(fd.accent, fd.display_name, fd.tagline, hours, Vector2(258, 196), fd.menu)
		var id2: StringName = fd.id
		c2.pressed.connect(func(): _pick_format(id2))
		fmts.add_child(c2)
		_fmt_cards[id2] = c2
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UITheme.label("Name", 20, "bold"))
	_name = LineEdit.new()
	_name.custom_minimum_size = Vector2(380, 0)
	_name.max_length = 28
	_name.text_changed.connect(func(_t): _name_edited = true)
	row.add_child(_name)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp2)
	var host := UITheme.button("Host Online", func(): _go(true), 20)
	row.add_child(host)
	var go := UITheme.button("Open for Business!", func(): _go(false), 24)
	go.name = "Go"
	row.add_child(go)
	_status = UITheme.label("", 17, "bold", Pal.UI_BAD)
	v.add_child(_status)
	_pick_location(location_id)
	_pick_format(format_id)


func _sorted(table: Dictionary, order: Array) -> Array:
	var arr := table.values()
	arr.sort_custom(func(a, b):
		var ia := order.find(String(a.id))
		var ib := order.find(String(b.id))
		ia = 99 if ia < 0 else ia
		ib = 99 if ib < 0 else ib
		return ia < ib or (ia == ib and String(a.id) < String(b.id)))
	return arr


func _supply_line(l: LocationDef) -> String:
	match l.supply_mode:
		"market":
			return "Ingredients: market stalls at every stop"
		"grow":
			return "Ingredients: grow them or print them"
	return "Ingredients: order a delivery truck"


## A selectable card: colour band with the name, a tagline, a detail line and
## (for restaurant types) the menu as pictures.
func _card(accent: Color, title: String, tagline: String, detail: String, size_px: Vector2, menu: Array, body := "") -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = size_px
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", UITheme.card(Color("fffaf0"), Pal.UI_INK_SOFT, 12, 2, false))
	b.add_theme_stylebox_override("hover", UITheme.card(Color("fff7e6"), Pal.UI_INK, 12, 3, false))
	b.add_theme_stylebox_override("pressed", UITheme.card(Color("fff2cf"), accent, 12, 5, false))
	b.add_theme_stylebox_override("hover_pressed", UITheme.card(Color("fff2cf"), accent, 12, 5, false))
	b.add_theme_stylebox_override("focus", UITheme.card(Color(0, 0, 0, 0), Pal.UI_ACCENT, 12, 3, false))
	b.focus_entered.connect(func(): Audio.play_ui(&"ui_hover", -6.0))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 10
	v.offset_bottom = -8
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	var band := PanelContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_theme_stylebox_override("panel", UITheme.card(accent, accent.darkened(0.25), 8, 2, false))
	var t := UITheme.label(title, 22, "bold", Color.WHITE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(t)
	v.add_child(band)
	var tl := UITheme.label(tagline, 16, "bold", Pal.UI_INK)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tl)
	if body != "":
		var bl := UITheme.label(body, 14, "regular", Pal.UI_INK)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bl)
	if not menu.is_empty():
		var icons := HBoxContainer.new()
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_theme_constant_override("separation", 2)
		for rid in menu:
			var tr := TextureRect.new()
			tr.custom_minimum_size = Vector2(52, 52)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture = IconRenderer.get_icon("recipe:%s" % rid)
			tr.tooltip_text = Content.display_name(rid)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icons.add_child(tr)
		v.add_child(icons)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var d := UITheme.label(detail, 14, "regular", Pal.UI_INK_SOFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	return b


func _pick_location(id: StringName) -> void:
	location_id = id
	for k in _loc_cards:
		(_loc_cards[k] as Button).set_pressed_no_signal(k == id)
	_confirm = false
	_status.text = ""
	preview_changed.emit(location_id, format_id)


func _pick_format(id: StringName) -> void:
	format_id = id
	for k in _fmt_cards:
		(_fmt_cards[k] as Button).set_pressed_no_signal(k == id)
	var fd: RestaurantFormatDef = Content.formats.get(id)
	if fd and not _name_edited:
		_name.text = fd.default_name
		_name_edited = false
	_confirm = false
	_status.text = ""
	preview_changed.emit(location_id, format_id)


func _go(host: bool) -> void:
	if Saves.has_save() and not _confirm:
		_confirm = true
		_status.text = "This replaces your current restaurant. Press again to confirm."
		Audio.play_ui(&"error")
		return
	var setup := {"location": String(location_id), "format": String(format_id), "name": _name.text.strip_edges()}
	started.emit(setup, host)


func focus_first() -> void:
	if _loc_cards.has(location_id):
		(_loc_cards[location_id] as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
