class_name PlayerChip
extends PanelContainer
## Bottom-of-screen card for one local player: identity colour, what they're
## holding, and the context actions available right now.

var player: PlayerCharacter
var _name: Label
var _held: Label
var _hints: HBoxContainer
var _last := ""


func _ready() -> void:
	var col := player.actor_color()
	var sb := UITheme.card(Color("fffaf0"), col, 12, 4)
	sb.border_width_left = 12
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(270, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_name = UITheme.label(player.player_name, 18, "display", col.darkened(0.25))
	row.add_child(_name)
	_held = UITheme.label("", 15, "bold", Pal.UI_INK_SOFT)
	_held.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_held.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_held.custom_minimum_size = Vector2(120, 0)
	row.add_child(_held)
	_hints = HBoxContainer.new()
	_hints.add_theme_constant_override("separation", 10)
	v.add_child(_hints)


func update_hint(h: Dictionary) -> void:
	if player == null or not is_instance_valid(player):
		return
	var held: Item = player.held()
	var held_text := ""
	if player.carried_fixture:
		held_text = player.carried_fixture.display_name()
	elif held:
		held_text = held.display_name()
	var parts := []
	var dev := player.device
	if h.has("grab") and h["grab"] != "":
		parts.push_back([Inputs.grab_hint(dev), h["grab"]])
	if h.has("use") and h["use"] != "":
		parts.push_back([Inputs.use_hint(dev), h["use"]])
	if h.has("alt"):
		parts.push_back([Inputs.alt_hint(dev), h["alt"]])
	elif h.get("lift", false) and held == null:
		parts.push_back(["Hold " + Inputs.grab_hint(dev), "Move"])
	var key := held_text + "|" + str(parts)
	if key == _last:
		return
	_last = key
	_held.text = ("· " + held_text) if held_text != "" else ""
	for c in _hints.get_children():
		c.queue_free()
	if parts.is_empty():
		_hints.add_child(UITheme.label(String(h.get("name", "")), 15, "regular", Pal.UI_INK_SOFT))
	for p in parts:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var keycap := PanelContainer.new()
		var ks := UITheme.card(Pal.UI_INK, Pal.UI_INK, 6, 0, false)
		ks.content_margin_left = 6
		ks.content_margin_right = 6
		ks.content_margin_top = 0
		ks.content_margin_bottom = 1
		keycap.add_theme_stylebox_override("panel", ks)
		keycap.add_child(UITheme.label(p[0], 13, "bold", Pal.UI_PAPER))
		box.add_child(keycap)
		var t := UITheme.label(String(p[1]), 15, "bold")
		box.add_child(t)
		_hints.add_child(box)
