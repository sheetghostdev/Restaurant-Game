class_name Dishwasher
extends FixtureComponent
## A commercial hood washer: load dirty dishes, press USE to run a cycle, take
## the clean stack out. Starts automatically when full. Can break down.

enum State { LOADING, RUNNING, DONE }

@export var capacity := 10
@export var cycle_time := 8.0
@export var hood_path: NodePath

var plates := 0
var mugs := 0
var state := State.LOADING
var t := 0.0
var _hood: Node3D
var _vis: DishStackVisual
var _fx_t := 0.0


func _ready() -> void:
	if not hood_path.is_empty():
		_hood = get_node_or_null(hood_path)
	_vis = DishStackVisual.new()
	_vis.position = Vector3(0, 0.84, 0)
	fixture.add_child.call_deferred(_vis)


func total() -> int:
	return plates + mugs


func query(actor: Node, verb: int) -> Dictionary:
	var held: Item = actor.held()
	if verb == GameConst.Verb.GRAB:
		if held is DishItem and (held as DishItem).dirty and state == State.LOADING:
			if total() + held.count() <= capacity:
				return {"label": "Load dishwasher"}
			return {"label": "Dishwasher is full", "blocked": true}
		if held == null and total() > 0 and state != State.RUNNING:
			return {"label": "Take %s dishes" % ("clean" if state == State.DONE else "dirty")}
		return {}
	if verb == GameConst.Verb.USE and state == State.LOADING and total() > 0 and fixture.is_working():
		return {"label": "Start wash cycle"}
	return {}


func perform(actor: Node, verb: int, _delta: float) -> bool:
	var held: Item = actor.held()
	if verb == GameConst.Verb.GRAB:
		if held is DishItem and (held as DishItem).dirty and state == State.LOADING:
			return auto_insert(actor.take_held())
		if held == null and total() > 0 and state != State.RUNNING:
			var pile: DishItem = world().spawn_item(&"dishware", {"p": plates, "m": mugs, "dt": state != State.DONE}, {"none": true})
			plates = 0
			mugs = 0
			state = State.LOADING
			actor.hold(pile)
			Audio.play_at(&"dish_stack", fixture.global_position)
			fixture.mark_dirty()
			return true
		return false
	if verb == GameConst.Verb.USE:
		return start()
	return false


func start() -> bool:
	if state != State.LOADING or total() <= 0 or not fixture.is_working():
		return false
	state = State.RUNNING
	t = 0.0
	Audio.play_at(&"ui_confirm", fixture.global_position)
	fixture.mark_dirty()
	return true


func auto_insert(it: Item) -> bool:
	if not (it is DishItem) or not (it as DishItem).dirty or state != State.LOADING:
		return false
	if total() + it.count() > capacity:
		return false
	plates += it.plates
	mugs += it.mugs
	world().despawn(it)
	Audio.play_at(&"dish_stack", fixture.global_position)
	if total() >= capacity:
		start()
	fixture.mark_dirty()
	return true


func server_tick(delta: float) -> void:
	if state == State.RUNNING and fixture.is_working():
		t += delta
		if t >= cycle_time:
			state = State.DONE
			Audio.play_at(&"dishwasher_done", fixture.global_position)
			world().stats_add(&"dishes_washed", total())
			fixture.mark_dirty()


func _process(delta: float) -> void:
	if fixture == null:
		return
	var running := state == State.RUNNING and fixture.is_working()
	if _hood:
		var target := 0.0 if running else 0.42
		_hood.position.y = lerpf(_hood.position.y, 0.82 + target, clampf(delta * 6.0, 0, 1))
		if running:
			_hood.position.x = sin(Time.get_ticks_msec() * 0.03) * 0.004
	if _vis:
		_vis.visible = not running
		_vis.show_counts(mini(plates, 8), mini(mugs, 6), state != State.DONE)
	Audio.loop(fixture, &"dishwasher_loop", running)
	if running and fixture.world:
		_fx_t -= delta
		if _fx_t <= 0.0:
			_fx_t = 0.5
			fixture.world.fx.steam(fixture.global_position + Vector3(0, 1.35, 0), 1.0, Color(1, 1, 1, 0.55), true)


func status_text() -> String:
	match state:
		State.RUNNING:
			return "Washing… %d%%" % roundi(100.0 * t / cycle_time)
		State.DONE:
			return "Clean! Take them out"
	return "%d/%d loaded" % [total(), capacity] if total() > 0 else ""


func get_state() -> Dictionary:
	return {"p": plates, "m": mugs, "s": state, "t": snappedf(t, 0.1)}


func set_state(d: Dictionary) -> void:
	plates = d.get("p", 0)
	mugs = d.get("m", 0)
	state = d.get("s", State.LOADING)
	t = d.get("t", 0.0)
