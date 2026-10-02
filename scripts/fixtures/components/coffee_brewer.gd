class_name CoffeeBrewer
extends FixtureComponent
## Load bags of beans into the hopper; put a clean mug on the drip tray and it
## brews automatically. Leave it too long and it overflows into a puddle.

@export var slot_index := 0
@export var capacity := 20
@export var servings_per_bag := 10
@export var beans_path: NodePath

var beans := 0
var _last_stage := -1
var _overflowed := false
var _beans_vis: Node3D
var _fx_t := 0.0


func _ready() -> void:
	if not beans_path.is_empty():
		_beans_vis = get_node_or_null(beans_path)


func _mug() -> DishItem:
	var s := fixture.slot(slot_index)
	if s and s.item is DishItem:
		var d := s.item as DishItem
		if d.is_mug() and d.is_single() and not d.dirty:
			return d
	return null


func _coffee(d: DishItem) -> Dictionary:
	for c in d.contents:
		if c["id"] == &"coffee":
			return c
	return {}


func query(actor: Node, verb: int) -> Dictionary:
	var held: Item = actor.held()
	if verb == GameConst.Verb.GRAB and held is FoodItem and held.def_id == &"coffee_beans":
		if beans + servings_per_bag <= capacity + servings_per_bag / 2:
			return {"label": "Refill beans"}
		return {"label": "Hopper is full", "blocked": true}
	return {}


func perform(actor: Node, verb: int, _delta: float) -> bool:
	var held: Item = actor.held()
	if verb == GameConst.Verb.GRAB and held is FoodItem and held.def_id == &"coffee_beans":
		if query(actor, verb).get("blocked", false):
			return false
		beans = mini(beans + servings_per_bag, capacity)
		world().despawn(held)
		Audio.play_at(&"crate_take", fixture.global_position, 0.0, 0.8)
		fixture.mark_dirty()
		return true
	return false


func server_tick(delta: float) -> void:
	var m := _mug()
	if m == null or not fixture.is_working():
		_last_stage = -1
		_overflowed = false
		return
	var c := _coffee(m)
	if c.is_empty():
		if not m.contents.is_empty():
			return
		if beans <= 0:
			return
		beans -= 1
		m.add_content(&"coffee", 0.0)
		m.rebuild_visual()
		m.mark_dirty()
		fixture.mark_dirty()
		Audio.play_at(&"coffee_brew_loop", fixture.global_position, -6.0)
		return
	var prof := Content.item(&"coffee").cook_profile
	var rate := prof.rate
	if prof.stage_index(float(c.get("ck", 0.0))) >= prof.perfect_stage:
		rate *= Difficulty.factor("overcook")   # more time before it overflows
	c["ck"] = float(c.get("ck", 0.0)) + rate * delta
	var st := prof.stage_index(c["ck"])
	if st != _last_stage:
		if _last_stage >= 0 and st == prof.perfect_stage:
			Audio.play_at(&"coffee_done", fixture.global_position)
			world().fx.sparkle(m.global_position + Vector3(0, 0.2, 0), Color("e9c9a0"))
		_last_stage = st
		m.refresh_visual()
		m.mark_dirty()
	if prof.fire_at > 0.0 and c["ck"] >= prof.fire_at and not _overflowed:
		_overflowed = true
		Audio.play_at(&"splash", fixture.global_position)
		world().disasters.spawn_mess(&"spill", fixture.global_position + fixture.front_vec() * 0.8)
		Events.notify("Coffee overflowed!", &"warning")


func _process(delta: float) -> void:
	if fixture == null:
		return
	if _beans_vis:
		var lvl := clampf(float(beans) / capacity, 0.0, 1.0)
		_beans_vis.visible = beans > 0
		_beans_vis.scale = Vector3(1, maxf(lvl * 0.2, 0.01), 1)
	var m := _mug()
	var brewing := m != null and not _coffee(m).is_empty() and fixture.is_working()
	Audio.loop(fixture, &"coffee_brew_loop", brewing)
	if brewing and fixture.world:
		_fx_t -= delta
		if _fx_t <= 0.0:
			_fx_t = 0.4
			fixture.world.fx.steam(m.global_position + Vector3(0, 0.18, 0), 0.6, Color(1, 1, 1, 0.55), true)


func status_text() -> String:
	if beans <= 0:
		return "Out of beans!"
	var m := _mug()
	if m:
		var c := _coffee(m)
		if not c.is_empty():
			return Content.item(&"coffee").cook_profile.stage_name(c["ck"])
	return "%d cups of beans left" % beans


func get_state() -> Dictionary:
	return {"b": beans}


func set_state(d: Dictionary) -> void:
	beans = d.get("b", beans)
