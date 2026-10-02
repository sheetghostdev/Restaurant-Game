class_name Sink
extends FixtureComponent
## Manual dishwashing. Drop dirty dishes in, hold USE to scrub them one by one;
## clean dishes collect on the drain board.

@export var capacity := 12
@export var wash_time := 1.25

var dirty_plates := 0
var dirty_mugs := 0
var clean_plates := 0
var clean_mugs := 0
var progress := 0.0
var _washing := 0.0
var _dirty_vis: DishStackVisual
var _clean_vis: DishStackVisual
var _sound_t := 0.0


func _ready() -> void:
	_dirty_vis = DishStackVisual.new()
	_dirty_vis.position = Vector3(-0.2, 0.62, 0)
	fixture.add_child.call_deferred(_dirty_vis)
	_clean_vis = DishStackVisual.new()
	_clean_vis.position = Vector3(0.22, 0.82, 0.02)
	fixture.add_child.call_deferred(_clean_vis)


func dirty_total() -> int:
	return dirty_plates + dirty_mugs


func clean_total() -> int:
	return clean_plates + clean_mugs


func query(actor: Node, verb: int) -> Dictionary:
	var held: Item = actor.held()
	if verb == GameConst.Verb.GRAB:
		if held is DishItem and (held as DishItem).dirty:
			if dirty_total() + held.count() <= capacity:
				return {"label": "Put in sink"}
			return {"label": "Sink is full", "blocked": true}
		if held == null and clean_total() > 0:
			return {"label": "Take clean dishes (%d)" % clean_total()}
		return {}
	if verb == GameConst.Verb.USE and dirty_total() > 0:
		return {"label": "Wash", "hold": true, "anim": CharacterRig.Anim.SCRUB, "progress": progress / wash_time}
	return {}


func perform(actor: Node, verb: int, delta: float) -> bool:
	var held: Item = actor.held()
	if verb == GameConst.Verb.GRAB:
		if held is DishItem and (held as DishItem).dirty:
			if dirty_total() + held.count() > capacity:
				return false
			dirty_plates += held.plates
			dirty_mugs += held.mugs
			world().despawn(held)
			Audio.play_at(&"dish_stack", fixture.global_position)
			fixture.mark_dirty()
			return true
		if held == null and clean_total() > 0:
			var p := mini(clean_plates, 10)
			var m := mini(clean_mugs, 10 - p)
			var pile: DishItem = world().spawn_item(&"dishware", {"p": p, "m": m}, {"none": true})
			clean_plates -= p
			clean_mugs -= m
			actor.hold(pile)
			Audio.play_at(&"dish_clink", fixture.global_position)
			fixture.mark_dirty()
			return true
		return false
	if verb == GameConst.Verb.USE:
		var speed: float = actor.get("work_speed") if actor.get("work_speed") != null else 1.0
		return wash(delta * speed)
	return false


func wash(amount: float) -> bool:
	if dirty_total() <= 0:
		return false
	progress += amount
	_washing = 0.3
	if progress >= wash_time:
		progress = 0.0
		if dirty_plates > 0:
			dirty_plates -= 1
			clean_plates += 1
		else:
			dirty_mugs -= 1
			clean_mugs += 1
		Audio.play_at(&"dish_clink", fixture.global_position, -4.0, randf_range(0.95, 1.1))
		if world():
			world().fx.bubbles(fixture.global_position + Vector3(-0.2, 0.85, 0))
			world().stats_add(&"dishes_washed", 1)
	fixture.mark_dirty()
	return true


func server_tick(delta: float) -> void:
	_washing = maxf(_washing - delta, 0.0)


func _process(delta: float) -> void:
	if _dirty_vis == null:
		return
	_dirty_vis.show_counts(mini(dirty_plates, 8), mini(dirty_mugs, 6), true)
	_clean_vis.show_counts(mini(clean_plates, 10), mini(clean_mugs, 6), false)
	if Net.is_authority():
		pass
	else:
		_washing = maxf(_washing - delta, 0.0)
	Audio.loop(fixture, &"wash_loop", _washing > 0.0)
	if _washing > 0.0 and fixture.world:
		_sound_t -= delta
		if _sound_t <= 0.0:
			_sound_t = 0.3
			fixture.world.fx.bubbles(fixture.global_position + Vector3(-0.2, 0.8, 0), true)


func status_text() -> String:
	if dirty_total() > 0:
		return "%d dirty · %d clean" % [dirty_total(), clean_total()]
	if clean_total() > 0:
		return "%d clean" % clean_total()
	return ""


func get_state() -> Dictionary:
	return {"dp": dirty_plates, "dm": dirty_mugs, "cp": clean_plates, "cm": clean_mugs, "pr": snappedf(progress, 0.05), "w": _washing > 0.0}


func set_state(d: Dictionary) -> void:
	dirty_plates = d.get("dp", 0)
	dirty_mugs = d.get("dm", 0)
	clean_plates = d.get("cp", 0)
	clean_mugs = d.get("cm", 0)
	progress = d.get("pr", 0.0)
	if d.get("w", false):
		_washing = 0.35


## Automation / staff entry point.
func auto_insert(it: Item) -> bool:
	if it is DishItem and (it as DishItem).dirty and dirty_total() + it.count() <= capacity:
		dirty_plates += it.plates
		dirty_mugs += it.mugs
		world().despawn(it)
		fixture.mark_dirty()
		return true
	return false
