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
	p.position = Vector2(-18 - 220, 16)
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


func _build_tickets() -> void:
	_tickets = HBoxContainer.new()
	_tickets.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tickets.position = Vector2(-300, 14)
	_tickets.custom_minimum_size = Vector2(600, 0)
	_tickets.alignment = BoxContainer.ALIGNMENT_CENTER
	_tickets.add_theme_constant_override("separation", 6)
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
	_toasts.position.y = 120 + (_forecast.size.y + 10 if _forecast.visible else 0)


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
	var key := ""
	for t in world.orders.tickets:
		key += "%d:%d|" % [t["id"], int(t["patience"] * 10)]
	if key == _ticket_key:
		return
	_ticket_key = key
	for c in _tickets.get_children():
		c.queue_free()
	var shown := 0
	for t in world.orders.tickets:
		if shown >= 12:
			var more := UITheme.label("+%d" % (world.orders.tickets.size() - shown), 22, "display")
			_tickets.add_child(more)
			break
		_tickets.add_child(_make_ticket(t))
		shown += 1


func _make_ticket(t: Dictionary) -> Control:
	var pat: float = t["patience"]
	var col := Pal.UI_GOOD if pat > 0.5 else (Pal.UI_WARN if pat > 0.25 else Pal.UI_BAD)
	var p := PanelContainer.new()
	var sb := UITheme.card(Color("fffaf0"), Pal.UI_INK, 8, 3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var tex := IconRenderer.get_icon("recipe:%s" % t["recipe"])
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(54, 54)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(tr)
	else:
		v.add_child(UITheme.label(Content.display_name(StringName(t["recipe"])), 14, "bold"))
	var tl := UITheme.label("T%d" % t["table"], 15, "display")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(54, 7)
	bar.max_value = 1.0
	bar.value = pat
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	v.add_child(bar)
	if pat < 0.25:
		var tw := p.create_tween().set_loops()
		tw.tween_property(p, "modulate", Color(1, 0.75, 0.75), 0.3)
		tw.tween_property(p, "modulate", Color.WHITE, 0.3)
	return p


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
