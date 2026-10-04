class_name ResultsScreen
extends Control
## End-of-day summary: the ledger, how the guests felt, what got used and
## what got wasted.

var hud: HUD
var _card: PanelContainer
var _body: VBoxContainer
var _continue: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.12, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = UITheme.panel()
	_card.custom_minimum_size = Vector2(860, 0)
	center.add_child(_card)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_card.add_child(_body)


func show_results(r: Dictionary) -> void:
	for c in _body.get_children():
		c.queue_free()
	var title := UITheme.heading("Day %d — Closed!" % int(r.get("day", 1)), 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	_body.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	left.add_child(UITheme.heading("The Till", 26, Pal.UI_ACCENT))
	_row(left, "Revenue (incl. tips)", GameConst.money(r.get("revenue", 0.0)), Pal.UI_MONEY)
	_row(left, "Expenses", GameConst.money(-r.get("expenses", 0.0)), Pal.UI_BAD)
	var profit: float = r.get("profit", 0.0)
	_row(left, "Profit", GameConst.money(profit), Pal.UI_MONEY if profit >= 0 else Pal.UI_BAD, true)
	_row(left, "Cash on hand", GameConst.money(r.get("money", 0.0)), Pal.UI_INK)
	left.add_child(HSeparator.new())
	left.add_child(UITheme.heading("The Guests", 26, Pal.UI_ACCENT))
	_row(left, "Customers served", str(r.get("people_served", 0)))
	_row(left, "Groups that walked out", str(r.get("groups_lost", 0)), Pal.UI_BAD if r.get("groups_lost", 0) > 0 else Pal.UI_INK)
	_row(left, "Turned away by the line", str(r.get("balked", 0)))
	_row(left, "Orders missed", str(r.get("orders_missed", 0)), Pal.UI_BAD if r.get("orders_missed", 0) > 0 else Pal.UI_INK)
	_row(left, "Dishes sent back", str(r.get("refused", 0)))
	_row(left, "Average satisfaction", "%d%%" % roundi(r.get("satisfaction", 0.0) * 100.0))
	var rd: float = r.get("reputation_delta", 0.0)
	_row(left, "Reputation", "%.1f★ (%s%.2f)" % [r.get("reputation", 0.0), "+" if rd >= 0 else "", rd], Pal.UI_GOOD if rd >= 0 else Pal.UI_BAD)
	right.add_child(UITheme.heading("The Kitchen", 26, Pal.UI_ACCENT))
	var ing: Array = r.get("ingredients", [])
	if ing.is_empty():
		right.add_child(UITheme.label("No ingredients used.", 18, "regular", Pal.UI_INK_SOFT))
	for i in mini(ing.size(), 8):
		_row(right, String(ing[i]["name"]), "×%d" % int(ing[i]["n"]))
	right.add_child(HSeparator.new())
	_row(right, "Food wasted", "%d (%s)" % [int(r.get("waste", 0)), GameConst.money(r.get("waste_cost", 0.0))], Pal.UI_BAD if r.get("waste", 0) > 0 else Pal.UI_INK)
	_row(right, "Dishes washed", str(r.get("dishes_washed", 0)))
	_row(right, "Fires", str(r.get("fires", 0)), Pal.UI_BAD if r.get("fires", 0) > 0 else Pal.UI_INK)
	_row(right, "Repairs", str(r.get("repairs", 0)))
	_consequences(r)
	var verdict := UITheme.label(_verdict(r), 20, "bold", Pal.UI_INK_SOFT)
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(verdict)
	_continue = UITheme.button("Continue to the evening  ▸", func(): Net.request("continue_results"), 24)
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(_continue)
	visible = true
	_card.scale = Vector2(0.9, 0.9)
	_card.pivot_offset = _card.size * 0.5
	create_tween().tween_property(_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_continue.grab_focus.call_deferred()
	Audio.play_ui(&"day_end")


## What today means for tomorrow, in plain words: walkouts cost stars and
## sales, and stars decide how many guests come.
func _consequences(r: Dictionary) -> void:
	var lines := []
	var lost := int(r.get("groups_lost", 0))
	if lost > 0:
		lines.push_back(["%d group%s walked out: −%.2f★ and %s in lost sales" % [lost, "" if lost == 1 else "s", float(r.get("rep_walkouts", 0.0)), GameConst.money(r.get("lost_sales", 0.0))], Pal.UI_BAD])
	var refused := int(r.get("refused", 0))
	if refused > 0:
		lines.push_back(["%d dish%s sent back (burnt, raw or spoiled)" % [refused, "" if refused == 1 else "es"], Pal.UI_BAD])
	var today := int(r.get("groups_planned", 0))
	var tomorrow := int(r.get("groups_tomorrow", 0))
	var rd := float(r.get("reputation_delta", 0.0))
	if tomorrow > 0:
		var why := "your reputation went up" if rd > 0.005 else ("your reputation dropped" if rd < -0.005 else "steady reputation")
		var col := Pal.UI_GOOD if rd > 0.005 else (Pal.UI_BAD if rd < -0.005 else Pal.UI_INK)
		lines.push_back(["Tomorrow: about %d groups (today %d) — %s" % [tomorrow, today, why], col])
	for g in r.get("goals", []):
		if g.get("done", false):
			lines.push_back(["Goal done: %s (+%s)" % [String(g["text"]), GameConst.money(g["reward"])], Pal.UI_GOOD])
		else:
			lines.push_back(["Goal missed: %s" % String(g["text"]), Pal.UI_INK_SOFT])
	var best := int(r.get("best_streak", 0))
	if best >= 3:
		lines.push_back(["Best streak: %d happy tables in a row" % best, Pal.UI_GOOD])
	if lines.is_empty():
		return
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.card(Color("fff7e6"), Pal.UI_INK_SOFT, 10, 2, false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	for l in lines:
		var lab := UITheme.label("• " + String(l[0]), 18, "bold", l[1])
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lab)
	_body.add_child(box)


func _row(parent: Control, k: String, v: String, col := Pal.UI_INK, big := false) -> void:
	var h := HBoxContainer.new()
	var a := UITheme.label(k, 19 if not big else 22, "body" if not big else "bold", Pal.UI_INK_SOFT if not big else Pal.UI_INK)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(UITheme.label(v, 19 if not big else 24, "bold" if not big else "display", col))
	parent.add_child(h)


func _verdict(r: Dictionary) -> String:
	var sat: float = r.get("satisfaction", 0.0)
	if r.get("people_served", 0) == 0:
		return "A quiet day. Tomorrow will be busier."
	if r.get("fires", 0) > 0 and sat > 0.7:
		return "There was a fire and people still loved it. Legendary."
	if sat > 0.85:
		return "Glowing reviews all round!"
	if sat > 0.65:
		return "Solid service. The regulars will be back."
	if r.get("groups_lost", 0) > 2:
		return "Too many people walked out. More hands — or more prep?"
	return "Rough day. Organise the kitchen and try again."


func _process(_delta: float) -> void:
	if visible and hud and hud.world and hud.world.day.phase != GameConst.Phase.RESULTS:
		visible = false
