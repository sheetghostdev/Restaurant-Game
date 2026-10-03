class_name DishRack
extends FixtureComponent
## Holds the restaurant's clean plates (or mugs). Dishware is a finite physical
## resource: when the rack is empty, someone needs to wash up.

@export_enum("plate", "mug") var kind := "plate"
@export var capacity := 14
@export var stack_offset := Vector3(0, 0.82, 0)

var count := 0
var _vis: DishStackVisual


func _ready() -> void:
	_vis = DishStackVisual.new()
	_vis.position = stack_offset
	fixture.add_child.call_deferred(_vis)


func _accepts(held: Item) -> bool:
	if not (held is DishItem):
		return false
	var d := held as DishItem
	if d.dirty or not d.contents.is_empty():
		return false
	var n := d.plates if kind == "plate" else d.mugs
	return n > 0 and count < capacity


## Holding food that can go on a clean plate (or in a mug): take one straight
## off the stack with the food already on it.
func _can_plate(held: Item) -> bool:
	return held is FoodItem and count > 0 and not (held as FoodItem).spoiled \
		and RecipeManager.can_start(kind, held.def_id)


func query(actor: Node, verb: int) -> Dictionary:
	if verb != GameConst.Verb.GRAB:
		return {}
	var held: Item = actor.held()
	if held == null:
		if count > 0:
			return {"label": "Take a %s" % kind}
		return {}
	if _can_plate(held):
		return {"label": "Put it on a %s" % kind}
	if _accepts(held):
		return {"label": "Put %ss away" % kind}
	return {}


func perform(actor: Node, verb: int, _delta: float) -> bool:
	if verb != GameConst.Verb.GRAB:
		return false
	var held: Item = actor.held()
	if held == null and count > 0:
		count -= 1
		var one: DishItem = world().spawn_item(&"dishware", {"p": 1 if kind == "plate" else 0, "m": 1 if kind == "mug" else 0}, {"none": true})
		actor.hold(one)
		Audio.play_at(&"dish_clink", fixture.global_position)
		fixture.mark_dirty()
		return true
	if _can_plate(held):
		count -= 1
		var food: Item = actor.take_held()
		var dish: DishItem = world().spawn_item(&"dishware", {"p": 1 if kind == "plate" else 0, "m": 1 if kind == "mug" else 0}, {"none": true})
		dish.receive(food)
		actor.hold(dish)
		dish.mark_dirty()
		Audio.play_at(&"dish_clink", fixture.global_position)
		fixture.mark_dirty()
		return true
	if _accepts(held):
		return auto_insert(held, actor)
	return false


## Deposits matching clean dishes; any other kind stays in the pile.
func auto_insert(it: Item, actor: Node = null) -> bool:
	if not _accepts(it):
		return false
	var d := it as DishItem
	var room := capacity - count
	if kind == "plate":
		var n := mini(d.plates, room)
		d.plates -= n
		count += n
	else:
		var n2 := mini(d.mugs, room)
		d.mugs -= n2
		count += n2
	if d.count() <= 0:
		world().despawn(d)
	else:
		d.rebuild_visual()
		d.mark_dirty()
	Audio.play_at(&"dish_stack", fixture.global_position)
	fixture.mark_dirty()
	return true


## Automation can pull single clean dishes out.
func auto_extract() -> Item:
	if count <= 0:
		return null
	count -= 1
	fixture.mark_dirty()
	return world().spawn_item(&"dishware", {"p": 1 if kind == "plate" else 0, "m": 1 if kind == "mug" else 0}, {"none": true})


func _process(_delta: float) -> void:
	if _vis:
		if kind == "plate":
			_vis.show_counts(count, 0, false)
		else:
			_vis.show_counts(0, count, false)


func status_text() -> String:
	return "%d clean %ss" % [count, kind] if count > 0 else "Out of %ss!" % kind


func get_state() -> Dictionary:
	return {"n": count}


func set_state(d: Dictionary) -> void:
	count = d.get("n", count)
