class_name HUD
extends Control
## Minimal in-game UI. The restaurant itself carries most information; the HUD
## adds the clock, money, reputation, order tickets, alerts, per-player hints
## and progress rings for work in progress.

var world: GameWorld
var icons: IconRenderer

var _day_label: Label
var _phase_label: Label
var _theme_label: Label          ## Train: "Next stop: Millbrook · 42 s"
var _clock_label: Label
var _day_bar: DayBar
var _money_label: Label
var _money_delta: Label
var _stars: StarMeter
var _star_delta: Label
var _streak: Label
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
var recipe_book: RecipeBook
var debug_panel: DebugPanel
var _shown_money := 0.0
var _ticket_key := ""
var _ticket_bars := {}       ## table number -> PaperTicket
var _top_left: Control
var _top_right: Control

const TICKET_GAP := 10.0
const TOP := 12.0            ## the ticket rail's top edge
const BOTTOM_BAND := 54.0    ## kept clear for the player chips


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
	recipe_book = RecipeBook.new()
	recipe_book.hud = self
	add_child(recipe_book)
	debug_panel = DebugPanel.new()
	debug_panel.hud = self
	add_child(debug_panel)
	Events.toast.connect(_on_toast)
	Events.alert.connect(_on_alert)
	Events.money_changed.connect(_on_money)
	Events.reputation_changed.connect(_on_reputation)
	Events.orders_changed.connect(_refresh_tickets)
	Events.phase_changed.connect(_on_phase)
	Events.day_results.connect(func(r): results.show_results(r))
	Events.catalog_requested.connect(func(p, tab): catalog.open_for(p, tab))


# -----------------------------------------------------------------------------
# Layout
# -----------------------------------------------------------------------------

func _build_top_left() -> void:
	var p := UITheme.panel()
	_top_left = p
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
	_theme_label = UITheme.label("", 16, "bold", Pal.UI_INK_SOFT)
	_theme_label.visible = false
	v.add_child(_theme_label)
	_day_bar = DayBar.new()
	_day_bar.hud = self
	_day_bar.custom_minimum_size = Vector2(230, 16)
	v.add_child(_day_bar)


func _build_top_right() -> void:
	var p := UITheme.panel()
	_top_right = p
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
	var srow := HBoxContainer.new()
	v.add_child(srow)
	_stars = StarMeter.new()
	srow.add_child(_stars)
	_star_delta = UITheme.label("", 17, "bold", Pal.UI_BAD)
	_star_delta.modulate.a = 0.0
	srow.add_child(_star_delta)
	_streak = UITheme.label("", 16, "bold", Pal.UI_GOOD)
	_streak.visible = false
	v.add_child(_streak)


## Order rail along the top, between the clock card and the money card: one
## card per table, most impatient first.
func _build_tickets() -> void:
	_tickets = HBoxContainer.new()
	_tickets.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tickets.offset_left = 292
	_tickets.offset_right = -252   # clear of the money card
	_tickets.offset_top = TOP
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
	_join_hint.position = Vector2(-520, -30)
	_join_hint.custom_minimum_size = Vector2(500, 0)
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
	if d.phase == GameConst.Phase.MORNING:
		# The doors open by themselves: count down to it.
		phase_text = "Prep · opens in %s" % GameConst.countdown(d.prep_left)
		var hurry := d.prep_left <= 15.0 and fmod(Time.get_ticks_msec() * 0.001, 0.6) < 0.3
		_phase_label.add_theme_color_override("font_color", Pal.UI_BAD if hurry else Pal.UI_ACCENT)
	elif d.phase == GameConst.Phase.SERVICE and d.is_rush():
		phase_text = "RUSH HOUR!"
		_phase_label.add_theme_color_override("font_color", Pal.UI_BAD)
	else:
		_phase_label.add_theme_color_override("font_color", Pal.UI_ACCENT if d.phase != GameConst.Phase.SERVICE else Pal.UI_GOOD)
	_phase_label.text = phase_text
	var tn := world.theme_node
	var tl: String = tn.status_line() if tn and tn.has_method("status_line") else ""
	_theme_label.visible = tl != ""
	_theme_label.text = tl
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
	var sk := world.day.streak
	_streak.visible = sk >= 2 and d.phase in [GameConst.Phase.SERVICE, GameConst.Phase.CLOSING]
	if _streak.visible:
		_streak.text = "STREAK ×%d · tips +%d%%" % [sk, roundi(world.day.tip_bonus() * 100.0)]
	_update_chips()
	_keep_clear()
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


## Reputation moves show next to the stars: green up, red down (with a
## shake), so it's obvious what a walkout or a great meal did.
func _on_reputation(v: float, d: float) -> void:
	_stars.value = v
	if absf(d) < 0.005:
		return
	_star_delta.text = " %s%.2f★" % ["+" if d > 0 else "−", absf(d)]
	_star_delta.add_theme_color_override("font_color", Pal.UI_GOOD if d > 0 else Pal.UI_BAD)
	_star_delta.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_star_delta, "modulate:a", 0.0, 0.8)
	if absf(d) >= 0.05:
		_stars.pivot_offset = _stars.size * 0.5
		_stars.modulate = Color(1.0, 0.55, 0.5) if d < 0 else Color(0.7, 1.0, 0.7)
		var pulse := create_tween()
		pulse.tween_property(_stars, "scale", Vector2.ONE * 1.2, 0.1)
		pulse.tween_property(_stars, "scale", Vector2.ONE, 0.25)
		pulse.parallel().tween_property(_stars, "modulate", Color.WHITE, 0.9)


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
		var gl: Array = fc.get("goals", [])
		if not gl.is_empty():
			_forecast_body.add_child(UITheme.label("Goals", 18, "bold", Pal.UI_ACCENT))
			for gtext in gl:
				var g2 := UITheme.label("☐ " + String(gtext), 16, "bold", Pal.UI_INK)
				g2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				g2.custom_minimum_size = Vector2(270, 0)
				_forecast_body.add_child(g2)
		for e in fc.get("f", []):
			var l := UITheme.label("• " + String(e), 16, "body", Pal.UI_WARN)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(270, 0)
			_forecast_body.add_child(l)
		var mode := world.location.supply_mode if world.location else "truck"
		var morning_tip := "Unload the truck, stock the fridge and prep food: the doors open by themselves when the countdown runs out."
		if mode == "market":
			morning_tip = "Shop at the depot market on the platform, stock the fridges and prep food: the train leaves when the countdown runs out."
		elif mode == "grow":
			morning_tip = "Harvest the planters, print what you need and prep food: the doors open when the countdown runs out."
		var tip := UITheme.label(morning_tip, 15, "regular", Pal.UI_INK_SOFT)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size = Vector2(270, 0)
		_forecast_body.add_child(tip)
	elif d.phase == GameConst.Phase.EVENING:
		_forecast_body.add_child(UITheme.heading("Evening", 26))
		var truck := world.location == null or world.location.supply_mode == "truck"
		var evening_tip := "Order tomorrow's supplies at the manager's desk: the truck only brings what you order. "
		if not truck:
			evening_tip = "Buy equipment, staff and upgrades at the manager's desk. "
		var tip2 := UITheme.label(evening_tip + "GRAB furniture to pick it up (hold GRAB if something is on it), Q to rotate. Expand at the FOR SALE signs. When you're ready, hold USE on the OPEN sign: lights out, and the next morning's prep starts.", 15, "regular", Pal.UI_INK_SOFT)
		tip2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip2.custom_minimum_size = Vector2(270, 0)
		_forecast_body.add_child(tip2)
		if not truck:
			pass
		elif world.deliveries.ordered_crates() == 0:
			_forecast_body.add_child(UITheme.label("Nothing ordered for tomorrow!", 17, "bold", Pal.UI_BAD))
		else:
			var cost := world.deliveries.order_cost()
			_forecast_body.add_child(UITheme.label("Tomorrow's delivery: %d crates, %s" % [world.deliveries.ordered_crates(), GameConst.money(cost)], 17, "bold"))


func _refresh_tickets() -> void:
	# Group dishes by table; the group's patience is shared by its tickets.
	var tables := {}
	for t in world.orders.tickets:
		var n := int(t["table"])
		if not tables.has(n):
			tables[n] = {"table": n, "patience": float(t["patience"]), "dishes": {}}
		var e: Dictionary = tables[n]
		e["patience"] = minf(e["patience"], float(t["patience"]))
		var code := RecipeManager.order_code({"recipe": t["recipe"], "extras": t.get("extras", [])})
		e["dishes"][code] = int(e["dishes"].get(code, 0)) + 1
	var list := tables.values()
	list.sort_custom(func(a, b): return a["patience"] < b["patience"] or (a["patience"] == b["patience"] and a["table"] < b["table"]))
	# As many slips as fit the rail; the rest are counted on a "+N" card.
	var shown := []
	var used := 0.0
	for i in list.size():
		var wdt := PaperTicket.estimate_width(list[i]["dishes"]) + TICKET_GAP
		var room := _tickets.size.x - (90.0 if i < list.size() - 1 else 0.0)
		if used + wdt > room and not shown.is_empty():
			break
		used += wdt
		shown.push_back(list[i])
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
			var ticket := PaperTicket.make(e)
			_ticket_bars[int(e["table"])] = ticket
			_tickets.add_child(ticket)
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



## The HUD must never hide the game: the camera frames the restaurant in
## the space between the top band (clock, tickets, money) and the player
## chips, and anything a local player walks behind fades out.
func _keep_clear() -> void:
	var vh := get_viewport_rect().size.y
	if vh <= 0.0:
		return
	var top := maxf(TOP + PaperTicket.BAND, _top_left.position.y + _top_left.size.y) + 6.0
	world.camera.safe_top = top / vh
	world.camera.safe_bottom = BOTTOM_BAND / vh
	var spots: Array[Vector2] = []
	var cam := world.camera
	for p in world.players():
		if p.is_local() and not cam.is_position_behind(p.global_position):
			spots.push_back(cam.unproject_position(p.global_position + Vector3(0, 0.9, 0)))
	var panels: Array = [_top_left, _top_right, _forecast, _toasts, _alerts]
	panels.append_array(_tickets.get_children())
	for c in panels:
		var ctl := c as Control
		if ctl == null or not ctl.visible:
			continue
		var r := ctl.get_global_rect().grow(36.0)
		var covered := false
		for sp in spots:
			if r.has_point(sp):
				covered = true
				break
		var want := 0.22 if covered else 1.0
		ctl.modulate.a = move_toward(ctl.modulate.a, want, get_process_delta_time() * 5.0)


func _set_ticket_patience(table: int, pat: float) -> void:
	var t: PaperTicket = _ticket_bars.get(table)
	if t and is_instance_valid(t):
		t.set_patience(pat)


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
	var hints := ["R: recipe book"]
	if n < GameConst.MAX_PLAYERS and Net.is_authority():
		if not Inputs.is_claimed(Inputs.KB_B) and Inputs.is_claimed(Inputs.KB_A):
			hints.push_back("Enter: 2nd keyboard player")
		hints.push_back("Gamepad (A): join")
	_join_hint.text = "  ·  ".join(hints)


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
