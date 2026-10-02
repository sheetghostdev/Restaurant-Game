class_name WorldOverlay
extends Control
## Screen-space rings drawn over the 3D world: hold-action progress for each
## local player and cooking progress (with the perfect zone marked) over every
## grill, fryer and coffee machine.

var hud: HUD
var _cookers: Array = []
var _scan := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0 and hud and hud.world and hud.world.grid:
		_scan = 1.0
		_cookers.clear()
		for f in hud.world.grid.all_fixtures():
			if f.get_component("Cooker") or f.get_component("CoffeeBrewer") or f.get_component("Processor"):
				_cookers.push_back(f)
	queue_redraw()


func _draw() -> void:
	if hud == null or hud.world == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for f in _cookers:
		if not is_instance_valid(f):
			continue
		_draw_fixture(cam, f)
	for p in hud.world.players():
		if not p.is_local():
			continue
		var h: Dictionary = hud.world.interaction.hint_for(p)
		var t = h.get("target")
		if t == null or not is_instance_valid(t):
			continue
		var pos: Vector3 = t.global_position + Vector3(0, 1.25, 0)
		if cam.is_position_behind(pos):
			continue
		var sp := cam.unproject_position(pos)
		if h.has("lift_progress"):
			_ring(sp + Vector2(0, -10), 20.0, h["lift_progress"], p.actor_color())
		elif h.has("progress") and p.in_use:
			_ring(sp + Vector2(0, -10), 20.0, clampf(h["progress"], 0.0, 1.0), p.actor_color())


func _ring(c: Vector2, r: float, t: float, col: Color) -> void:
	draw_circle(c, r + 5.0, Color(Pal.UI_INK, 0.85))
	draw_circle(c, r - 4.0, Color(Pal.UI_PAPER, 0.95))
	draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * t, 40, col, 7.0, true)


func _draw_fixture(cam: Camera3D, f: Fixture) -> void:
	var cook := f.get_component("Cooker") as Cooker
	if cook:
		var it := cook.cooking_item()
		if it and f.is_working():
			_cook_ring(cam, it.global_position, it.def.cook_profile, it.cook)
		return
	var brew := f.get_component("CoffeeBrewer") as CoffeeBrewer
	if brew:
		var s := f.slot(brew.slot_index)
		if s and s.item is DishItem:
			for c in (s.item as DishItem).contents:
				if c["id"] == &"coffee":
					_cook_ring(cam, s.item.global_position, Content.item(&"coffee").cook_profile, c.get("ck", 0.0))
		return
	var proc := f.get_component("Processor") as Processor
	if proc:
		var w := proc.work_item()
		if w and w.chop > 0.0:
			var pos := w.global_position + Vector3(0, 0.45, 0)
			if not cam.is_position_behind(pos):
				var sp := cam.unproject_position(pos) + Vector2(24, -16)
				_ring(sp, 10.0, w.chop / w.def.chop_work, Pal.UI_ACCENT)


func _cook_ring(cam: Camera3D, at: Vector3, p: CookProfile, progress: float) -> void:
	var pos := at + Vector3(0, 0.15, 0)
	if cam.is_position_behind(pos):
		return
	# Sit the ring beside the food (up and to the right) so the food stays visible.
	var sp := cam.unproject_position(pos) + Vector2(26, -30)
	var r := 11.0
	var max_p := p.fire_at if p.fire_at > 0.0 else p.stage_ends[p.stage_ends.size() - 2] * 1.2
	draw_circle(sp, r + 5.0, Color(Pal.UI_INK, 0.85))
	var start := 0.0
	for i in p.stage_ends.size():
		var end := minf(p.stage_ends[i], max_p)
		if end <= start:
			continue
		var a0 := -PI / 2.0 + TAU * start / max_p
		var a1 := -PI / 2.0 + TAU * end / max_p
		var q := p.stage_quality[i]
		var col := Pal.UI_GOOD if q >= 0.95 else (Color("e6d07a") if q >= 0.6 else (Color("c9b8a3") if i < p.perfect_stage else Pal.UI_BAD))
		draw_arc(sp, r, a0, a1, 16, Color(col, 0.7), 6.0, true)
		start = end
	var pa := -PI / 2.0 + TAU * clampf(progress, 0.0, max_p) / max_p
	draw_arc(sp, r, -PI / 2.0, pa, 40, Color(1, 1, 1, 0.95), 3.0, true)
	draw_line(sp, sp + Vector2(cos(pa), sin(pa)) * (r + 4.0), Pal.UI_INK, 3.0, true)
	var st := p.stage_index(progress)
	if p.stage_quality[st] >= 0.95:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		draw_arc(sp, r + 8.0, 0, TAU, 32, Color(Pal.UI_GOOD, 0.5 + pulse * 0.5), 3.0, true)
