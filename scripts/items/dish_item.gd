class_name DishItem
extends Item
## Plates and mugs. A single clean dish can hold food (and is matched against
## recipes); several dishes form a stack/pile (clean or dirty) that is carried
## and washed together.

var plates := 1
var mugs := 0
var dirty := false
var contents: Array = []   # [{ "id": StringName, "ck": float, "sd": bool }]

var _parts: Array[Node3D] = []
var _wobble_t := 0.0

## Dirty piles taller than this wobble in a player's hands and may topple.
const SAFE_STACK := 4


func count() -> int:
	return plates + mugs


func is_single() -> bool:
	return count() == 1


func is_mug() -> bool:
	return mugs > 0 and plates == 0


func is_empty_clean() -> bool:
	return is_single() and not dirty and contents.is_empty()


func content_ids() -> Array:
	var ids := []
	for c in contents:
		ids.push_back(c["id"])
	return ids


func matches(tag: String) -> bool:
	if tag == "mug":
		return is_mug()
	if tag == "plate":
		return plates > 0 and mugs == 0
	if tag == "clean_dish":
		return not dirty and contents.is_empty()
	if tag == "dirty_dish":
		return dirty
	if tag == "ovenable":
		return not content_on(&"oven").is_empty()
	return super.matches(tag)


## The first content that cooks on `heat` (the dough of a pizza), if this is
## a single clean dish. The record is live: cookers write its "ck".
func content_on(heat: StringName) -> Dictionary:
	if not is_single() or dirty:
		return {}
	for c in contents:
		var d := Content.item(c["id"])
		if d and d.cook_profile and d.cook_profile.heat == heat:
			return c
	return {}


func recipe() -> RecipeDef:
	return RecipeManager.match_dish(self)


func quality() -> float:
	return RecipeManager.dish_quality(self)


func display_name() -> String:
	if dirty:
		return "Dirty dishes ×%d" % count() if count() > 1 else ("Dirty " + DishPlating.cup_word().to_lower() if is_mug() else "Dirty plate")
	if count() > 1:
		if mugs == 0:
			return "Plates ×%d" % plates
		if plates == 0:
			return "%s ×%d" % [DishPlating.cup_word(true), mugs]
		return "Dishes ×%d" % count()
	var r := recipe()
	if r:
		return r.display_name
	if contents.is_empty():
		return DishPlating.cup_word() if is_mug() else "Plate"
	var names := []
	for c in contents:
		names.push_back(Content.display_name(c["id"]))
	return ", ".join(names)


func status_text() -> String:
	if is_single() and not contents.is_empty():
		var r := recipe()
		var q := quality()
		if r == null:
			return "Incomplete"
		return RecipeManager.quality_word(q)
	return ""


# -----------------------------------------------------------------------------
# Combination
# -----------------------------------------------------------------------------

func can_receive(other: Item) -> bool:
	if other is FoodItem:
		return not other.spoiled and RecipeManager.can_add_food(self, other.def_id)
	if other is DishItem:
		return can_stack_with(other)
	return false


func can_stack_with(other: DishItem) -> bool:
	if other == self:
		return false
	if not contents.is_empty() or not other.contents.is_empty():
		return false
	if dirty != other.dirty:
		return false
	return count() + other.count() <= max_stack()


func max_stack() -> int:
	return 10


## 0 for a steady pile, up to 1 for a full dirty stack of 10.
func topple_risk() -> float:
	if not dirty or count() <= SAFE_STACK:
		return 0.0
	return float(count() - SAFE_STACK) / float(max_stack() - SAFE_STACK)


func on_slot_changed() -> void:
	super.on_slot_changed()
	set_process(true)


func _process(delta: float) -> void:
	super._process(delta)
	if visual == null:
		return
	# A tall dirty pile in someone's hands sways: the warning before it falls.
	var r := topple_risk() if holder() is PlayerCharacter else 0.0
	if r > 0.0:
		_wobble_t += delta * (5.0 + r * 7.0)
		var amp := 0.04 + r * 0.16
		visual.rotation = Vector3(sin(_wobble_t * 0.83) * amp * 0.6, 0.0, sin(_wobble_t) * amp)
		set_process(true)
	elif visual.rotation != Vector3.ZERO:
		visual.rotation = Vector3.ZERO


func receive(other: Item) -> void:
	if other is FoodItem:
		add_content(other.def_id, other.cook, other.spoiled)
		world.despawn(other)
	elif other is DishItem:
		plates += other.plates
		mugs += other.mugs
		world.despawn(other)
	rebuild_visual()
	bump()
	mark_dirty()


func add_content(id: StringName, ck := 0.0, sd := false) -> void:
	var c := {"id": id, "ck": ck}
	if sd:
		c["sd"] = true
	contents.push_back(c)


## Take one dish off a stack.
func can_take_one() -> bool:
	return count() > 1


func take_one() -> Item:
	if count() <= 1:
		return null
	var one: DishItem = world.spawn_item(&"dishware", {}, {"none": true})
	if plates > 0:
		plates -= 1
		one.plates = 1
		one.mugs = 0
	else:
		mugs -= 1
		one.plates = 0
		one.mugs = 1
	one.dirty = dirty
	one.rebuild_visual()
	one.mark_dirty()
	rebuild_visual()
	mark_dirty()
	return one


func make_dirty() -> void:
	contents.clear()
	dirty = true
	rebuild_visual()
	mark_dirty()


func clear_contents() -> Array:
	var old := contents.duplicate()
	contents.clear()
	rebuild_visual()
	mark_dirty()
	return old


# -----------------------------------------------------------------------------
# Visuals
# -----------------------------------------------------------------------------

func _build_model() -> void:
	_parts.clear()
	if count() > 1:
		_build_stack()
		return
	if is_mug():
		var key := DishPlating.vessel_key(contents, dirty)
		visual.add_child(Models.instance(key))
		if key == &"mug":
			DishPlating.fill_mug(contents, visual, _parts)
		return
	visual.add_child(Models.instance(&"plate_dirty" if dirty else &"plate"))
	if not contents.is_empty():
		DishPlating.build(self, visual, _parts)


func _build_stack() -> void:
	var y := 0.0
	for k in plates:
		var p := Models.instance(&"plate_dirty" if dirty else &"plate")
		p.position = Vector3(0, y, 0)
		p.rotation.y = k * 0.7
		visual.add_child(p)
		y += 0.034
	for k in mugs:
		var m := Models.instance(DishPlating.vessel_key([], dirty))
		if plates > 0:
			m.position = Vector3(0.27, (k / 3) * 0.125, -0.12 + (k % 3) * 0.12)
		else:
			m.position = Vector3(((k % 2) - 0.5) * 0.17, (k / 4) * 0.125, (((k / 2) % 2) - 0.5) * 0.17)
		m.rotation.y = k * 1.3
		visual.add_child(m)


func refresh_visual() -> void:
	for p in _parts:
		if not is_instance_valid(p):
			continue
		var c: Dictionary = p.get_meta(&"content", {})
		if c.is_empty():
			continue
		var d := Content.item(c["id"])
		var col := Color.WHITE
		if d and d.cook_profile:
			col = d.cook_profile.color_at(c.get("ck", 0.0))
		set_mult(col, p)
		set_tint(Pal.SPOILED, 0.6 if c.get("sd", false) else 0.0, p)


# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------

func get_state() -> Dictionary:
	var d := super.get_state()
	d["p"] = plates
	d["m"] = mugs
	if dirty:
		d["dt"] = true
	if not contents.is_empty():
		var arr := []
		for c in contents:
			var e := {"id": String(c["id"]), "ck": snappedf(c.get("ck", 0.0), 0.001)}
			if c.get("sd", false):
				e["sd"] = true
			arr.push_back(e)
		d["c"] = arr
	return d


func set_state(d: Dictionary) -> void:
	super.set_state(d)
	plates = d.get("p", 1)
	mugs = d.get("m", 0)
	dirty = d.get("dt", false)
	contents.clear()
	for e in d.get("c", []):
		var c := {"id": StringName(e["id"]), "ck": float(e.get("ck", 0.0))}
		if e.get("sd", false):
			c["sd"] = true
		contents.push_back(c)
	rebuild_visual()
