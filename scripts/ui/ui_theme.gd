class_name UITheme
## The game's UI look: warm paper cards with thick ink outlines, a chunky slab
## serif for headings (Alfa Slab One) and a friendly sans for text (Rubik).
## Built in code so every screen shares one source of truth.

static var _theme: Theme
static var _fonts := {}


static func font(kind := "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path := "res://art/fonts/Rubik-Medium.ttf"
	match kind:
		"display": path = "res://art/fonts/AlfaSlabOne-Regular.ttf"
		"bold": path = "res://art/fonts/Rubik-Bold.ttf"
		"regular": path = "res://art/fonts/Rubik-Regular.ttf"
	var f: Font = load(path)
	_fonts[kind] = f
	return f


static func card(bg := Pal.UI_PAPER, border := Pal.UI_INK, radius := 14, border_w := 3, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if shadow:
		s.shadow_color = Color(0.1, 0.07, 0.05, 0.28)
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, 5)
	s.anti_aliasing = true
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 20
	# Labels
	t.set_color("font_color", "Label", Pal.UI_INK)
	# Buttons
	var normal := card(Pal.UI_PAPER, Pal.UI_INK, 12, 3)
	var hover := card(Color("fff7e6"), Pal.UI_INK, 12, 3)
	var pressed := card(Pal.UI_PAPER_DARK, Pal.UI_INK, 12, 3, false)
	var focus := card(Color("fff2cf"), Pal.UI_ACCENT, 12, 4)
	var disabled := card(Color("e6ddcd"), Color("a89b8c"), 12, 3, false)
	for s in [normal, hover, pressed, focus, disabled]:
		s.content_margin_top = 8
		s.content_margin_bottom = 8
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", Pal.UI_INK)
	t.set_color("font_hover_color", "Button", Pal.UI_INK)
	t.set_color("font_pressed_color", "Button", Pal.UI_INK)
	t.set_color("font_focus_color", "Button", Pal.UI_INK)
	t.set_color("font_disabled_color", "Button", Color("a89b8c"))
	t.set_font("font", "Button", font("bold"))
	t.set_font_size("font_size", "Button", 20)
	# Panels
	t.set_stylebox("panel", "PanelContainer", card())
	t.set_stylebox("panel", "Panel", card())
	# LineEdit
	var le := card(Color("fffaf0"), Pal.UI_INK, 10, 3, false)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", card(Color("fffaf0"), Pal.UI_ACCENT, 10, 3, false))
	t.set_color("font_color", "LineEdit", Pal.UI_INK)
	t.set_color("caret_color", "LineEdit", Pal.UI_INK)
	# Sliders / progress
	var track := StyleBoxFlat.new()
	track.bg_color = Pal.UI_PAPER_DARK
	track.set_corner_radius_all(6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Pal.UI_ACCENT
	fill.set_corner_radius_all(6)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0, 0, 0, 0.15)
	pb_bg.set_corner_radius_all(5)
	var pb_fg := StyleBoxFlat.new()
	pb_fg.bg_color = Pal.UI_GOOD
	pb_fg.set_corner_radius_all(5)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fg)
	t.set_font_size("font_size", "ProgressBar", 1)
	# Tabs
	t.set_stylebox("tab_selected", "TabBar", card(Pal.UI_PAPER, Pal.UI_INK, 10, 3, false))
	t.set_stylebox("tab_unselected", "TabBar", card(Pal.UI_PAPER_DARK, Pal.UI_INK_SOFT, 10, 2, false))
	t.set_stylebox("tab_hovered", "TabBar", card(Color("fff7e6"), Pal.UI_INK, 10, 3, false))
	t.set_stylebox("tab_focus", "TabBar", card(Color("fff2cf"), Pal.UI_ACCENT, 10, 3, false))
	t.set_color("font_selected_color", "TabBar", Pal.UI_INK)
	t.set_color("font_unselected_color", "TabBar", Pal.UI_INK_SOFT)
	t.set_color("font_hovered_color", "TabBar", Pal.UI_INK)
	t.set_font("font", "TabBar", font("bold"))
	# Check boxes / option buttons share the button look
	for cls in ["CheckBox", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("focus", cls, focus)
		t.set_color("font_color", cls, Pal.UI_INK)
		t.set_color("font_hover_color", cls, Pal.UI_INK)
		t.set_color("font_pressed_color", cls, Pal.UI_INK)
		t.set_color("font_focus_color", cls, Pal.UI_INK)
	# Scrollbars
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.08)
	sb.set_corner_radius_all(6)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Pal.UI_INK_SOFT
	grab.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", sb)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_color("font_color", "RichTextLabel", Pal.UI_INK)
	t.set_color("default_color", "RichTextLabel", Pal.UI_INK)
	_theme = t
	return t


static func label(text: String, size := 20, kind := "body", color := Pal.UI_INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func heading(text: String, size := 34, color := Pal.UI_INK) -> Label:
	return label(text, size, "display", color)


static func button(text: String, cb: Callable, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		Audio.play_ui(&"ui_click")
		cb.call())
	b.focus_entered.connect(func(): Audio.play_ui(&"ui_hover", -6.0))
	b.mouse_entered.connect(func(): Audio.play_ui(&"ui_hover", -8.0))
	return b


static func panel(bg := Pal.UI_PAPER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card(bg))
	return p


static func stars_text(rep: float) -> String:
	var full := int(floor(rep))
	var half := (rep - full) >= 0.5
	var s := ""
	for i in 5:
		if i < full:
			s += "★"
		elif i == full and half:
			s += "☆"
		else:
			s += "·"
	return s
