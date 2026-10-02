class_name CatalogUI
extends Control
## The manager's desk: buy equipment (delivered as boxes to the loading dock),
## set the standing supply order or place rush orders, hire staff, buy
## upgrades and expansions. Fully navigable with keyboard or gamepad.

var hud: HUD
var player: PlayerCharacter
var _tabs: HBoxContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _money: Label
var _tab := "equipment"
var _refresh_t := 0.0

const TABS := [["equipment", "Equipment"], ["supplies", "Supplies"], ["staff", "Staff"], ["upgrades", "Upgrades"], ["expansions", "Expansions"]]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.07, 0.1, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := UITheme.panel()
	card.custom_minimum_size = Vector2(980, 640)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(UITheme.heading("Supplier Catalog", 36))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_money = UITheme.heading("$0", 30, Pal.UI_MONEY)
	head.add_child(_money)
	var close_btn := UITheme.button("Close ✕", close)
	head.add_child(close_btn)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	v.add_child(_tabs)
	for t in TABS:
		var id: String = t[0]
		var b := UITheme.button(t[1], func(): _select(id))
		b.toggle_mode = true
		b.name = id
		_tabs.add_child(b)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)


func open_for(p: Node) -> void:
	player = p as PlayerCharacter
	visible = true
	Audio.play_ui(&"ui_confirm")
	_select(_tab)


func close() -> void:
	visible = false
	player = null
	Audio.play_ui(&"ui_back")


func blocks(p: PlayerCharacter) -> bool:
	return visible and p == player


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or hud == null:
		return
	_money.text = GameConst.money(hud.world.economy.money)
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.5
		_update_affordability()


func _select(id: String) -> void:
	_tab = id
	for b in _tabs.get_children():
		(b as Button).button_pressed = b.name == id
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	match id:
		"equipment": _build_equipment()
		"supplies": _build_supplies()
		"staff": _build_staff()
		"upgrades": _build_upgrades()
		"expansions": _build_expansions()
	var first := _first_button(_content)
	if first:
		first.grab_focus.call_deferred()
	else:
		(_tabs.get_child(0) as Button).grab_focus.call_deferred()


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and not (c as Button).disabled:
			return c
		var r := _first_button(c)
		if r:
			return r
	return null


func _row(icon_key: String, title: String, desc: String, right: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.card(Color("fffaf0"), Pal.UI_INK_SOFT, 10, 2, false))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var tex := IconRenderer.get_icon(icon_key)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(72, 72)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = tex
	h.add_child(tr)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UITheme.label(title, 22, "bold"))
	var d := UITheme.label(desc, 16, "regular", Pal.UI_INK_SOFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	h.add_child(v)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(right)
	_content.add_child(p)
	return p


func _buy_button(text: String, price: float, cb: Callable, enabled := true) -> Button:
	var b := UITheme.button("%s  %s" % [text, GameConst.money(price)], cb)
	b.custom_minimum_size = Vector2(170, 0)
	b.set_meta(&"price", price)
	b.disabled = not enabled
	return b


func _update_affordability() -> void:
	for b in _all_buttons(_content):
		if b.has_meta(&"price") and not b.has_meta(&"locked"):
			b.disabled = hud.world.economy.money < float(b.get_meta(&"price"))


func _all_buttons(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is Button:
			out.push_back(c)
		out.append_array(_all_buttons(c))
	return out


# -----------------------------------------------------------------------------
# Tabs
# -----------------------------------------------------------------------------

func _build_equipment() -> void:
	var w := hud.world
	var defs: Array = Content.sorted_values(Content.fixtures)
	defs.sort_custom(func(a, b): return a.category < b.category or (a.category == b.category and a.price < b.price))
	var last_cat := ""
	for fd in defs:
		if not fd.purchasable:
			continue
		if fd.category != last_cat:
			last_cat = fd.category
			_content.add_child(UITheme.heading(fd.category.capitalize(), 22, Pal.UI_ACCENT))
		var locked: bool = fd.unlock_day > w.day.day or fd.unlock_reputation > w.economy.reputation
		var id: StringName = fd.id
		var b := _buy_button("Buy", fd.price, func(): Net.request("buy_fixture", [String(id)]), not locked)
		if locked:
			b.text = "Day %d · %.1f★" % [fd.unlock_day, fd.unlock_reputation]
			b.set_meta(&"locked", true)
		_row("fixture:%s" % fd.id, fd.display_name, fd.description, b)


func _build_supplies() -> void:
	var w := hud.world
	var hint := UITheme.label("Standing order arrives every morning (paid on delivery). Rush orders cost %d%% more and arrive in under a minute." % roundi((DeliveryManager.RUSH_MARKUP - 1.0) * 100), 16, "regular", Pal.UI_INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(hint)
	_content.add_child(UITheme.label("Tomorrow's delivery: %s" % GameConst.money(w.deliveries.standing_order_cost()), 18, "bold"))
	for s in Content.sorted_values(Content.supplies):
		var sd := s as SupplyDef
		var id: StringName = sd.id
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		var qty: int = w.deliveries.standing_order.get(id, 0)
		var minus := UITheme.button("−", func():
			Net.request("standing", [String(id), int(w.deliveries.standing_order.get(id, 0)) - 1])
			_refresh_later())
		var lbl := UITheme.label("%d" % qty, 24, "display")
		lbl.custom_minimum_size = Vector2(32, 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plus := UITheme.button("+", func():
			Net.request("standing", [String(id), int(w.deliveries.standing_order.get(id, 0)) + 1])
			_refresh_later())
		var rush := _buy_button("Rush ×1", sd.price * DeliveryManager.RUSH_MARKUP, func(): Net.request("rush_order", [String(id), 1]))
		box.add_child(minus)
		box.add_child(lbl)
		box.add_child(plus)
		box.add_child(rush)
		var stock := w.inventory.units(sd.item_id)
		var desc := "%d per %s · %s each · in stock: %d%s" % [sd.quantity, sd.container.replace("_", " "), GameConst.money(sd.price), stock, " · keep cold!" if sd.needs_cold else ""]
		_row("item:%s" % sd.item_id, sd.display_name, desc, box)


func _refresh_later() -> void:
	get_tree().create_timer(0.15).timeout.connect(func():
		if visible and _tab == "supplies":
			var focus := get_viewport().gui_get_focus_owner()
			var idx := _all_buttons(_content).find(focus)
			_select("supplies")
			var btns := _all_buttons(_content)
			if idx >= 0 and idx < btns.size():
				(btns[idx] as Button).grab_focus.call_deferred())


func _build_staff() -> void:
	var w := hud.world
	var hint := UITheme.label("Staff handle repetitive work so you can handle the chaos. Wages are paid at the end of each day.", 16, "regular", Pal.UI_INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(hint)
	for s in Content.sorted_values(Content.staff):
		var sd := s as StaffDef
		var id: StringName = sd.id
		var locked := sd.unlock_day > w.day.day
		var b := _buy_button("Hire", sd.hire_cost, func(): Net.request("hire", [String(id)]), not locked)
		if locked:
			b.text = "Day %d" % sd.unlock_day
			b.set_meta(&"locked", true)
		_row("staff:%s" % sd.id, sd.display_name, "%s\nWage: %s/day" % [sd.description, GameConst.money(sd.daily_wage)], b)
	var current := w.staff.workers()
	if not current.is_empty():
		_content.add_child(UITheme.heading("Your team", 22, Pal.UI_ACCENT))
		for wk in current:
			var worker := wk as Worker
			var nid: int = worker.net_id
			var d := UITheme.button("Let go", func():
				Net.request("dismiss", [nid])
				_refresh_later_tab("staff"))
			_row("staff:%s" % worker.def_id, worker.display_name(), worker.status_text(), d)


func _refresh_later_tab(t: String) -> void:
	get_tree().create_timer(0.2).timeout.connect(func():
		if visible and _tab == t:
			_select(t))


func _build_upgrades() -> void:
	var w := hud.world
	for u in Content.sorted_values(Content.upgrades):
		var ud := u as UpgradeDef
		var id: StringName = ud.id
		var owned: bool = w.build.has_upgrade(id) and not ud.repeatable
		var locked := ud.unlock_day > w.day.day
		var b := _buy_button("Buy", ud.price, func():
			Net.request("buy_upgrade", [String(id)])
			_refresh_later_tab("upgrades"), not owned and not locked)
		if owned:
			b.text = "Owned"
			b.set_meta(&"locked", true)
		elif locked:
			b.text = "Day %d" % ud.unlock_day
			b.set_meta(&"locked", true)
		_row("model:flatpack", ud.display_name, ud.description, b)


func _build_expansions() -> void:
	var w := hud.world
	var calm := w.is_calm()
	var hint := UITheme.label("Expansions are built between services. You can also buy them at the FOR SALE signs around the building.", 16, "regular", Pal.UI_INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(hint)
	var avail := w.build.available_expansions()
	if avail.is_empty():
		_content.add_child(UITheme.label("Nothing left to build here — for now.", 18, "bold"))
	for e in avail:
		var id: StringName = e.id
		var b := _buy_button("Build", e.price, func():
			Net.request("buy_expansion", [String(id)])
			_refresh_later_tab("expansions"), calm)
		if not calm:
			b.text = "After closing"
			b.set_meta(&"locked", true)
		_row("model:for_sale_sign", e.display_name, e.description, b)
