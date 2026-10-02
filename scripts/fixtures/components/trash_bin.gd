class_name TrashBin
extends FixtureComponent
## Throw away food, scrape plates, and take the bag out when it's full.

@export var capacity := 12
@export var lid_path: NodePath
@export var outdoor_dumpster := false   ## Accepts bags, crates and anything big.

var fill := 0
var _lid: Node3D
var _lid_t := 0.0


func _ready() -> void:
	if not lid_path.is_empty():
		_lid = get_node_or_null(lid_path)


func _can_take(held: Item) -> String:
	if held == null:
		return ""
	if outdoor_dumpster:
		if held is TrashItem or held is CrateItem or held is PackageItem or held is FoodItem:
			return "Throw away"
		if held is DishItem and not (held as DishItem).contents.is_empty():
			return "Scrape plate"
		return ""
	if fill >= capacity:
		return "FULL"
	if held is FoodItem:
		return "Throw away"
	if held is DishItem and not (held as DishItem).contents.is_empty():
		return "Scrape plate"
	return ""


func query(actor: Node, verb: int) -> Dictionary:
	if verb != GameConst.Verb.GRAB:
		return {}
	var held: Item = actor.held()
	var verdict := _can_take(held)
	if verdict == "FULL":
		return {"label": "Bin is full — take the bag out", "blocked": true}
	if verdict != "":
		return {"label": verdict}
	if held == null and fill > 0 and not outdoor_dumpster:
		return {"label": "Take out the trash"}
	return {}


func perform(actor: Node, verb: int, _delta: float) -> bool:
	if verb != GameConst.Verb.GRAB:
		return false
	var held: Item = actor.held()
	var verdict := _can_take(held)
	if verdict == "FULL":
		Audio.play_at(&"error", fixture.global_position)
		return false
	if verdict != "":
		_lid_t = 0.6
		Audio.play_at(&"trash", fixture.global_position)
		if held is DishItem:
			var old: Array = (held as DishItem).clear_contents()
			_count_waste(old.size(), old)
		else:
			_count_waste_item(held)
			world().despawn(held)
		if not outdoor_dumpster:
			fill += 1
		fixture.mark_dirty()
		return true
	if held == null and fill > 0 and not outdoor_dumpster:
		fill = 0
		_lid_t = 0.6
		var bag := world().spawn_item(&"trash_bag", {}, {"none": true})
		actor.hold(bag)
		Audio.play_at(&"trash", fixture.global_position, 0.0, 0.8)
		fixture.mark_dirty()
		return true
	return false


func _count_waste(n: int, contents: Array) -> void:
	for c in contents:
		var d := Content.item(c["id"])
		world().stats_add(&"waste", 1, c["id"])
		world().stats_add(&"waste_cost", d.unit_cost if d else 1.0)


func _count_waste_item(it: Item) -> void:
	if it is FoodItem:
		world().stats_add(&"waste", 1, it.def_id)
		world().stats_add(&"waste_cost", it.def.unit_cost)
	elif it is CrateItem and (it as CrateItem).count > 0:
		var cr := it as CrateItem
		var cd := cr.content_def()
		world().stats_add(&"waste", cr.count, cr.content_id)
		world().stats_add(&"waste_cost", cr.count * (cd.unit_cost if cd else 1.0))


func _process(delta: float) -> void:
	if _lid:
		_lid_t = maxf(_lid_t - delta, 0.0)
		var open := -1.1 if _lid_t > 0.0 else 0.0
		_lid.rotation.x = lerpf(_lid.rotation.x, open, clampf(delta * 12.0, 0, 1))


func status_text() -> String:
	if outdoor_dumpster:
		return "Bags, empty crates, spoiled stock"
	if fill >= capacity:
		return "FULL"
	return "%d/%d" % [fill, capacity] if fill > 0 else ""


func get_state() -> Dictionary:
	return {"f": fill}


func set_state(d: Dictionary) -> void:
	fill = d.get("f", 0)
