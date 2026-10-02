class_name HUD
extends Control
## Minimal in-game UI. The restaurant itself carries most information; the HUD
## adds the clock, money, reputation, order tickets, alerts, per-player hints
## and progress rings for work in progress.

var world: GameWorld
var icons: IconRenderer

var _day_label: Label
var _phase_label: Label
var _clock_label: Label
var _day_bar: DayBar
var _money_label: Label
var _money_delta: Label
var _stars: StarMeter
var _tickets: HBoxContainer
var _alerts: VBoxContainer
var _toasts: VBoxContainer
var _banner: Label
var _chips: HBoxContainer
var _join_hint: Label
var _forecast: PanelContainer
var _forecast_body: VBoxContainer
var _overlay: WorldOverlay
var _alert_rows := {}
var _chip_rows := {}
var results: ResultsScreen
var catalog: CatalogUI
var pause_menu: PauseMenu
var debug_panel: DebugPanel
var _shown_money := 0.0
var _ticket_key := ""
var _ticket_bars := {}       ## table number -> [ProgressBar, StyleBoxFlat, PanelContainer]

const TICKET_W := 196.0
const TICKET_GAP := 10.0
const TICKET_ICON := 54.0


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()
	icons = IconRenderer.new()
	add_child(icons)
	_overlay = WorldOverlay.new()
	_overlay.hud = self
	add_child(_overlay)
	_build_top_left()
	_build_top_right()
	_build_tickets()
	_build_alerts()
	_build_toasts()
	_build_banner()
	_build_chips()
	_build_forecast()
	results = ResultsScreen.new()
	results.hud = self
	add_child(results)
	catalog = CatalogUI.new()
	catalog.hud = self
	add_child(catalog)
	pause_menu = PauseMenu.new()
	pause_menu.hud = self
	add_child(pause_menu)
	debug_panel = DebugPanel.new()
	debug_panel.hud = self
	add_child(debug_panel)
	Events.toast.connect(_on_toast)
	Events.alert.connect(_on_alert)
	Events.money_changed.connect(_on_money)
	Events.reputation_changed.connect(func(v, _d): _stars.value = v)
	Events.orders_changed.connect(_refresh_tickets)
	Events.phase_changed.connect(_on_phase)
	Events.day_results.connect(func(r): results.show_results(r))
	Events.catalog_requested.connect(func(p): catalog.open_for(p))


# -----------------------------------------------------------------------------
# Layout
# -----------------------------------------------------------------------------

func _build_top_left() -> void:
	var p := UITheme.panel()
	p.position = Vector2(18, 16)
	p.custom_minimum_size = Vector2(250, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	_day_label = UITheme.heading("DAY 1", 30)
	row.add_child(_day_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_clock_label = UITheme.label("8:00am", 24, "bold")
	row.add_child(_clock_label)
	_phase_label = UITheme.label("Morning Prep", 18, "bold", Pal.UI_ACCENT)
	v.add_child(_phase_label)
	_day_bar = DayBar.new()
	_day_bar.hud = self
	_day_bar.custom_minimum_size = Vector2(230, 16)
	v.add_child(_day_bar)


func _build_top_right() -> void:
	var p := UITheme.panel()
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.position = Vector2(-18, 16)   # right edge 18 px in; grows leftwards
	p.custom_minimum_size = Vector2(220, 0)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	_money_label = UITheme.heading("$0", 32, Pal.UI_MONEY)
	row.add_child(_money_label)
	_money_delta = UITheme.label("", 18, "bold", Pal.UI_MONEY)
	_money_delta.modulate.a = 0.0
	row.add_child(_money_delta)
	_stars = StarMeter.new()
	v.add_child(_stars)


## Order rail along the top, between the clock card and the money card: one
## card per table, most impatient first.
func _build_tickets() -> void:
	_tickets = HBoxContainer.new()
	_tickets.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tickets.offset_left = 292
	_tickets.offset_right = -252   # clear of the money card
	_tickets.offset_top = 12
	_tickets.alignment = BoxContainer.ALIGNMENT_CENTER
	_tickets.add_theme_constant_override("separation", int(TICKET_GAP))
	_tickets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tickets)


func _build_alerts() -> void:
	_alerts = VBoxContainer.new()
	_alerts.position = Vector2(18, 150)
	_alerts.add_theme_constant_override("separation", 6)
	add_child(_alerts)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.position = Vector2(-18 - 340, 120)
	_toasts.custom_minimum_size = Vector2(340, 0)
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


func _build_banner() -> void:
	_banner = UITheme.heading("", 64)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(-500, -170)
	_banner.custom_minimum_size = Vector2(1000, 0)
	_banner.add_theme_constant_override("outline_size", 18)
	_banner.add_theme_color_override("font_outline_color", Pal.UI_INK)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)


func _build_chips() -> void:
	_chips = HBoxContainer.new()
	_chips.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_chips.position = Vector2(-640, -96)
	_chips.custom_minimum_size = Vector2(1280, 0)
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 12)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chips)
	_join_hint = UITheme.label("", 15, "bold", Color(1, 1, 1, 0.85))
	_join_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_join_hint.position = Vector2(-380, -30)
	_join_hint.custom_minimum_size = Vector2(360, 0)
	_join_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_join_hint.add_theme_constant_override("outline_size", 6)
	_join_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_child(_join_hint)


func _build_forecast() -> void:
	_forecast = UITheme.panel(Color("fbf4e6"))
	_forecast.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_forecast.position = Vector2(-18 - 300, 120)
	_forecast.custom_minimum_size = Vector2(300, 0)
	add_child(_forecast)
	_forecast_body = VBoxContainer.new()
	_forecast_body.add_theme_constant_override("separation", 4)
	_forecast.add_child(_forecast_body)


# -----------------------------------------------------------------------------
# Updates
# -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or world.day == null:
		return
	var d := world.day
	_day_label.text = "DAY %d" % d.day
	_clock_label.text = GameConst.clock_text(d.hour)
	var phase_text := d.phase_name()
	if d.phase == GameConst.Phase.SERVICE and d.is_rush():
		phase_text = "RUSH HOUR!"
		_phase_label.add_theme_color_override("font_color", Pal.UI_BAD)
	else:
		_phase_label.add_theme_color_override("font_color", Pal.UI_ACCENT if d.phase != GameConst.Phase.SERVICE else Pal.UI_GOOD)
	_phase_label.text = phase_text
	_day_bar.queue_redraw()
	# Money count-up
	var target := world.economy.money
	if absf(_shown_money - target) > 0.5:
		_shown_money = lerpf(_shown_money, target, clampf(delta * 6.0, 0, 1))
	else:
		_shown_money = target
	_money_label.text = GameConst.money(_shown_money)
	_money_label.add_theme_color_override("font_color", Pal.UI_MONEY if target >= 0 else Pal.UI_BAD)
	_stars.value = world.economy.reputation
	_update_chips()
	_forecast.visible = d.phase == GameConst.Phase.MORNING or d.phase == GameConst.Phase.EVENING
	if _forecast.visible and Engine.get_process_frames() % 30 == 0:
		_refresh_forecast()
	# Tips and toasts sit under the money card, the forecast, or the order
	# cards, whichever reaches furthest down.
	var ty := 120.0 + (_forecast.size.y + 10.0 if _forecast.visible else 0.0)
	if _tickets.get_child_count() > 0:
		ty = maxf(ty, _tickets.position.y + _tickets.get_combined_minimum_size().y + 12.0)
	_toasts.position.y = ty


func _on_money(_amount: float, delta: float) -> void:
	if absf(delta) < 0.5:
		return
	_money_delta.text = " %s%s" % ["+" if delta > 0 else "", GameConst.money(delta)]
	_money_delta.add_theme_color_override("font_color", Pal.UI_MONEY if delta > 0 else Pal.UI_BAD)
	_money_delta.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(_money_delta, "modulate:a", 0.0, 0.6)
	var tw2 := create_tween()
	_money_label.pivot_offset = _money_label.size * 0.5
	tw2.tween_property(_money_label, "scale", Vector2.ONE * 1.15, 0.08)
	tw2.tween_property(_money_label, "scale", Vector2.ONE, 0.2)


func _on_phase(phase: int) -> void:
	_refresh_forecast()
	if phase == GameConst.Phase.SERVICE:
		_forecast.visible = false
	if phase != GameConst.Phase.RESULTS:
		results.visible = false


func _refresh_forecast() -> void:
	for c in _forecast_body.get_children():
		c.queue_free()
	var d := world.day
	var fc: Dictionary = world.replicator.shared.get(&"forecast", {})
	if d.phase == GameConst.Phase.MORNING:
		_forecast_body.add_child(UITheme.heading("Today", 26))
		var groups: int = fc.get("g", 0)
		_forecast_body.add_child(UITheme.label("Expected: ~%d groups" % groups, 18, "bold"))
		var rh: Array = fc.get("rh", [])
		if not rh.is_empty():
			var hours := []
			for h in rh:
				hours.push_back(GameConst.clock_text(float(h)).replace(":00", ""))
			_forecast_body.add_child(UITheme.label("Rushes: " + ", ".join(hours), 17, "body", Pal.UI_BAD))
		for e in fc.get("f", []):
			var l := UITheme.label("• " + String(e), 16, "body", Pal.UI_WARN)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(270, 0)
			_forecast_body.add_child(l)
		var tip := UITheme.label("Unload the truck, stock the fridge, prep food — then hold USE on the OPEN sign.", 15, "regular", Pal.UI_INK_SOFT)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(270, 0)
		_forecast_body.add_child(tip)
	elif d.phase == GameConst.Phase.EVENING:
		_forecast_body.add_child(UITheme.heading("Evening", 26))
		var tip2 := UITheme.label("Build mode: hold GRAB on furniture to move it, Q to rotate. Use the manager's desk to buy equipment, hire staff and set tomorrow's delivery. Expand at the FOR SALE signs. Hold USE on the sign to end the day.", 15, "regular", Pal.UI_INK_SOFT)
		tip2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip2.custom_minimum_size = Vector2(270, 0)
		_forecast_body.add_child(tip2)
		var cost := world.deliveries.standing_order_cost()
		_forecast_body.add_child(UITheme.label("Tomorrow's delivery: %s" % GameConst.money(cost), 17, "bold"))


func _refresh_tickets() -> void:
	# Group dishes by table; the group's patience is shared by its tickets.
	var tables := {}
	for t in world.orders.tickets:
		var n := int(t["table"])
		if not tables.has(n):
			tables[n] = {"table": n, "patience": float(t["patience"]), "dishes": {}}
		var e: Dictionary = tables[n]
		e["patience"] = minf(e["patience"], float(t["patience"]))
		var rid := String(t["recipe"])
		e["dishes"][rid] = int(e["dishes"].get(rid, 0)) + 1
	var list := tables.values()
	list.sort_custom(func(a, b): return a["patience"] < b["patience"] or (a["patience"] == b["patience"] and a["table"] < b["table"]))
	var fit := maxi(1, int((_tickets.size.x + TICKET_GAP) / (TICKET_W + TICKET_GAP)))
	var shown := list.slice(0, fit if list.size() <= fit else fit - 1)
	# Rebuild only when the set of tables or dishes changes; otherwise just
	# move the patience bars.
	var key := ""
	for e in shown:
		key += "%d:%s;" % [e["table"], JSON.stringify(e["dishes"])]
	key += "+%d" % (list.size() - shown.size())
	if key != _ticket_key:
		_ticket_key = key
		_ticket_bars.clear()
		for c in _tickets.get_children():
			c.queue_free()
		for e in shown:
			_tickets.add_child(_make_ticket(e))
		if list.size() > shown.size():
			var more := PanelContainer.new()
			more.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			more.add_theme_stylebox_override("panel", UITheme.card(Pal.UI_INK, Pal.UI_INK, 12, 3))
			var ml := UITheme.label("+%d\ntables" % (list.size() - shown.size()), 22, "display", Pal.UI_PAPER)
			ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			more.add_child(ml)
			_tickets.add_child(more)
	for e in shown:
		_set_ticket_patience(int(e["table"]), float(e["patience"]))



func _make_ticket(e: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(TICKET_W, 0)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sb := UITheme.card(Color("fffaf0"), Pal.UI_INK, 12, 3)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	# Header: big table number on an ink strip
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Pal.UI_INK
	hsb.corner_radius_top_left = 9
	hsb.corner_radius_top_right = 9
	hsb.content_margin_top = 3
	hsb.content_margin_bottom = 3
	head.add_theme_stylebox_override("panel", hsb)
	var n: int = e["table"]
	var hl := UITheme.label("TABLE %d" % n if n > 0 else "TAKEAWAY", 24, "display", Pal.UI_PAPER)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(hl)
	v.add_child(head)
	# One row per dish: icon, name, count
	var dishes: Dictionary = e["dishes"]
	for rid in dishes:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(4, 0)
		row.add_child(pad)
		# Icon on a darker tile so the white plate doesn't vanish into the card
		var tile := PanelContainer.new()
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color("d9c9ae")
		tsb.set_corner_radius_all(10)
		tile.add_theme_stylebox_override("panel", tsb)
		var tr := TextureRect.new()
		tr.texture = IconRenderer.get_icon("recipe:%s" % rid)
		tr.custom_minimum_size = Vector2(TICKET_ICON, TICKET_ICON)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.add_child(tr)
		row.add_child(tile)
		var dish_label := UITheme.label(_short_dish_name(StringName(rid)), 18, "bold")
		dish_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dish_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dish_label.clip_text = true
		row.add_child(dish_label)
		var count: int = dishes[rid]
		if count > 1:
			var cl := UITheme.label("×%d" % count, 22, "display", Pal.UI_BAD)
			cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(cl)
		var pad2 := Control.new()
		pad2.custom_minimum_size = Vector2(4, 0)
		row.add_child(pad2)
		v.add_child(row)
	# Patience: a thick bar that turns yellow, then red and pulses
	var bar_row := MarginContainer.new()
	bar_row.add_theme_constant_override("margin_left", 10)
	bar_row.add_theme_constant_override("margin_right", 10)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = 1.0
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Pal.UI_PAPER_DARK
	bg.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("fill", fill)
	bar_row.add_child(bar)
	v.add_child(bar_row)
	_ticket_bars[n] = [bar, fill, p]
	return p


func _set_ticket_patience(table: int, pat: float) -> void:
	var refs: Array = _ticket_bars.get(table, [])
	if refs.is_empty():
		return
	var bar: ProgressBar = refs[0]
	var fill: StyleBoxFlat = refs[1]
	var p: PanelContainer = refs[2]
	bar.value = pat
	fill.bg_color = Pal.UI_GOOD if pat > 0.5 else (Pal.UI_WARN if pat > 0.25 else Pal.UI_BAD)
	var urgent := pat < 0.25
	if urgent and not p.has_meta("pulse"):
		var tw := p.create_tween().set_loops()
		tw.tween_property(p, "modulate", Color(1, 0.72, 0.72), 0.35)
		tw.tween_property(p, "modulate", Color.WHITE, 0.35)
		p.set_meta("pulse", tw)


## Short recipe name for tickets ("Classic Burger" -> "Burger").
static func _short_dish_name(id: StringName) -> String:
	var r := Content.recipe(id)
	return r.ticket_name() if r else Content.display_name(id)


func _on_alert(id: StringName, text: String, active: bool) -> void:
	if not active:
		if _alert_rows.has(id):
			_alert_rows[id].queue_free()
			_alert_rows.erase(id)
		return
	var row: PanelContainer = _alert_rows.get(id)
	if row == null:
		row = PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.card(Color("fde3d9"), Pal.UI_BAD, 10, 3))
		var l := UITheme.label(text, 18, "bold", Pal.UI_BAD)
		row.add_child(l)
		_alerts.add_child(row)
		_alert_rows[id] = row
		row.pivot_offset = Vector2(0, 16)
		row.scale = Vector2(0.6, 0.6)
		create_tween().tween_property(row, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		(row.get_child(0) as Label).text = text


func _on_toast(text: String, kind: StringName, color: Color) -> void:
	if kind == &"big":
		_banner.text = text
		_banner.add_theme_color_override("font_color", color if color.a > 0 else Pal.UI_PAPER)
		_banner.pivot_offset = _banner.size * 0.5
		_banner.scale = Vector2(0.5, 0.5)
		_banner.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.6)
		tw.tween_property(_banner, "modulate:a", 0.0, 0.5)
		return
	var bg := Color("fffaf0")
	var border := Pal.UI_INK
	match kind:
		&"warning":
			bg = Color("fdf0d2")
			border = Pal.UI_WARN
		&"error":
			bg = Color("fde3d9")
			border = Pal.UI_BAD
		&"tip":
			bg = Color("e3f1ec")
			border = Pal.UI_ACCENT
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.card(bg, border, 10, 3))
	var l := UITheme.label(text, 17, "bold")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	p.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 5:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	p.modulate.a = 0.0
	var tw2 := p.create_tween()
	tw2.tween_property(p, "modulate:a", 1.0, 0.2)
	tw2.tween_interval(9.0 if kind == &"tip" else 4.5)
	tw2.tween_property(p, "modulate:a", 0.0, 0.5)
	tw2.tween_callback(p.queue_free)


func _update_chips() -> void:
	var live := {}
	var locals := []
	for p in world.players():
		if p.is_local():
			locals.push_back(p)
	for p in locals:
		live[p] = true
		var chip: PlayerChip = _chip_rows.get(p)
		if chip == null:
			chip = PlayerChip.new()
			chip.player = p
			_chips.add_child(chip)
			_chip_rows[p] = chip
		chip.update_hint(world.interaction.hint_for(p))
	for p in _chip_rows.keys():
		if not live.has(p):
			if is_instance_valid(_chip_rows[p]):
				_chip_rows[p].queue_free()
			_chip_rows.erase(p)
	var n := world.players().size()
	if n < GameConst.MAX_PLAYERS and Net.is_authority():
		var hints := []
		if not Inputs.is_claimed(Inputs.KB_B) and Inputs.is_claimed(Inputs.KB_A):
			hints.push_back("Enter: 2nd keyboard player")
		hints.push_back("Gamepad (A): join")
		_join_hint.text = "  ·  ".join(hints)
	else:
		_join_hint.text = ""


func is_modal_open() -> bool:
	return results.visible or catalog.visible or pause_menu.visible


## Inner class: the day progress bar with rush-hour zones.
class DayBar extends Control:
	var hud: HUD

	func _draw() -> void:
		if hud == null or hud.world == null:
			return
		var d := hud.world.day
		var fmt := hud.world.format
		var r := Rect2(Vector2(0, 4), Vector2(size.x, size.y - 6))
		draw_rect(r, Color(0, 0, 0, 0.12), true)
		if fmt == null:
			return
		var span := float(fmt.close_hour - fmt.open_hour)
		var fc: Dictionary = hud.world.replicator.shared.get(&"forecast", {})
		for h in fc.get("rh", []):
			var x0 := (float(h) - fmt.open_hour) / span * size.x
			draw_rect(Rect2(Vector2(x0, r.position.y), Vector2(size.x / span, r.size.y)), Color(Pal.UI_BAD, 0.35), true)
		var t := 0.0
		if d.phase == GameConst.Phase.SERVICE:
			t = clampf((d.hour - fmt.open_hour) / span, 0.0, 1.0)
		elif d.phase >= GameConst.Phase.CLOSING:
			t = 1.0
		draw_rect(Rect2(r.position, Vector2(size.x * t, r.size.y)), Color(Pal.UI_ACCENT, 0.85), true)
		draw_rect(r, Pal.UI_INK, false, 2.0)
