class_name DebugPanel
extends PanelContainer
## Developer tools (F1). Every command runs on the authority via Net.request.

var hud: HUD
var _info: Label
var _arch_i := 0
var _dis_i := 0
var show_states := false

const DISASTERS := ["grease_fire", "dishwasher_breakdown", "fridge_failure", "machine_breakdown", "pipe_leak", "surprise_delivery", "health_inspection", "equipment_jam"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_theme_stylebox_override("panel", UITheme.card(Color(0.12, 0.11, 0.13, 0.92), Pal.MUSTARD, 10, 2))
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	position = Vector2(18, -260)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	v.add_child(UITheme.label("DEBUG (F1)", 18, "display", Pal.MUSTARD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	var cmds := [
		["Spawn customers", func():
			var archs := Content.archetypes.keys()
			archs.sort()
			Net.request("debug", ["spawn_customer", String(archs[_arch_i % archs.size()])])
			_arch_i += 1],
		["Spawn delivery", func(): Net.request("debug", ["spawn_delivery"])],
		["+ $500", func(): Net.request("debug", ["give_money", 500])],
		["Advance 1 hour", func(): Net.request("debug", ["advance_time", 1.0])],
		["Start service", func(): Net.request("debug", ["start_service"])],
		["End service", func(): Net.request("debug", ["end_service"])],
		["Cause disaster", func():
			Net.request("debug", ["disaster", DISASTERS[_dis_i % DISASTERS.size()]])
			_dis_i += 1],
		["Rep +1★", func(): Net.request("debug", ["reputation", 1.0])],
		["Toggle nav debug", func(): hud.world.toggle_nav_debug()],
		["Toggle AI states", func(): show_states = not show_states],
		["Spoil a crate", func(): Net.request("debug", ["spoil"])],
		["Clear customers", func(): Net.request("debug", ["clear_customers"])],
		["Reset restaurant", func(): get_tree().call_group(&"main", "debug_reset")],
		["Save now", func(): Net.request("save")],
	]
	for c in cmds:
		var b := Button.new()
		b.text = c[0]
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(c[1])
		b.focus_mode = Control.FOCUS_NONE
		grid.add_child(b)
	_info = UITheme.label("", 13, "regular", Color(0.9, 0.9, 0.85))
	_info.custom_minimum_size = Vector2(300, 0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_info)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if hud and hud.world:
		hud.world.show_ai_states = show_states and visible
	if not visible or hud == null or hud.world == null:
		return
	var w := hud.world
	var inv := []
	for k in w.inventory.counts:
		inv.push_back("%s %d" % [Content.display_name(k), w.inventory.counts[k]])
	var targets := []
	for p in w.players():
		var t = w.interaction.target_of(p)
		targets.push_back("%s→%s" % [p.player_name, t.display_name() if t and t.has_method("display_name") else "-"])
	_info.text = "Phase %s  h=%.2f  groups=%d  orders=%d  seats=%d\nEntities %d  FPS %d\nStock: %s\nTargets: %s\nMesses %d  fires %d" % [
		w.day.phase_name(), w.day.hour, w.customers.active_groups(), w.orders.tickets.size(), w.customers.total_seats(),
		w.entities.size(), Engine.get_frames_per_second(), ", ".join(inv), "  ".join(targets), w.disasters.mess_count(), w.disasters.active_fires]
