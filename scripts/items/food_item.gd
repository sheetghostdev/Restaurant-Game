class_name FoodItem
extends Item
## An ingredient or prepared component. Tracks cooking and chopping progress.

var cook := 0.0
var chop := 0.0
var left := -1          ## Batches (a tray of muffins): portions still in it.
var _model: Node3D

## Where the portions of a batch sit on its tray (a 2 × 2 muffin tin).
const PORTION_SPOTS := [Vector3(-0.075, 0.035, -0.075), Vector3(0.075, 0.035, -0.075), Vector3(-0.075, 0.035, 0.075), Vector3(0.075, 0.035, 0.075)]


func portions_left() -> int:
	return left if left >= 0 else def.portions


func _build_model() -> void:
	if def.base_model != &"":
		visual.add_child(Models.instance(def.base_model))
	if def.portions > 0:
		# The tin stays silver; only the batter in it browns.
		_model = Node3D.new()
		for k in mini(portions_left(), PORTION_SPOTS.size()):
			var m := Models.instance(def.model)
			m.position = PORTION_SPOTS[k]
			_model.add_child(m)
		visual.add_child(_model)
		return
	_model = Models.instance(def.model)
	visual.add_child(_model)


## A stand-alone model of `d` cooked to `ck` (icons, recipe book): the tin
## and every portion for batches.
static func make_model(d: ItemDef, ck := 0.0) -> Node3D:
	var root := Node3D.new()
	if d.base_model != &"":
		root.add_child(Models.instance(d.base_model))
	var tinted := Node3D.new()
	if d.portions > 0:
		for k in mini(d.portions, PORTION_SPOTS.size()):
			var m := Models.instance(d.model)
			m.position = PORTION_SPOTS[k]
			tinted.add_child(m)
	else:
		tinted.add_child(Models.instance(d.model))
	if d.cook_profile:
		tinted.set_meta(&"content", {"id": d.id, "ck": ck})
	root.add_child(tinted)
	return root


func refresh_visual() -> void:
	if _model == null:
		return
	var c := Color.WHITE
	if def.cook_profile:
		c = def.cook_profile.color_at(cook)
	set_mult(c, _model)
	set_tint(Pal.SPOILED, 0.6 if spoiled else 0.0, _model)


func display_name() -> String:
	var n := super.display_name()
	if def.cook_profile and not spoiled:
		n += " (%s)" % def.cook_profile.stage_name(cook)
	if def.portions > 0:
		n += " ×%d" % portions_left()
	return n


# --- Batches: USE takes one portion (onto a plate you're holding, or into
# your hands), cooked just like the batch. The empty tin is cleared away.

func use_query(actor: Node) -> Dictionary:
	if def.portions <= 0 or portions_left() <= 0 or spoiled:
		return {}
	var pd := Content.item(def.portion_item)
	var name := pd.display_name if pd else "one"
	if def.cook_profile and stage() < def.cook_profile.perfect_stage:
		return {"label": "Bake it first", "blocked": true}
	var held: Item = actor.held()
	if held == null:
		return {"label": "Take a %s" % name.to_lower()}
	if held is DishItem and RecipeManager.can_add_food(held as DishItem, def.portion_item):
		return {"label": "Add a %s" % name.to_lower()}
	return {}


func use_perform(actor: Node, _delta: float) -> bool:
	if use_query(actor).is_empty() or use_query(actor).get("blocked", false):
		return false
	var held: Item = actor.held()
	var one: FoodItem = world.spawn_item(def.portion_item, {"ck": cook}, {"none": true})
	if one == null:
		return false
	if held is DishItem:
		held.receive(one)
	else:
		actor.hold(one)
	Audio.play_at(&"crate_take", global_position)
	left = portions_left() - 1
	if left <= 0:
		world.despawn(self)
	else:
		rebuild_visual()
		bump()
		mark_dirty()
	return true


func quality() -> float:
	if spoiled:
		return 0.0
	if def.cook_profile:
		return def.cook_profile.quality(cook)
	return 1.0


func stage() -> int:
	return def.cook_profile.stage_index(cook) if def.cook_profile else 0


func is_untouched() -> bool:
	return cook <= 0.0 and chop <= 0.0 and not spoiled


func can_cook_on(heat: StringName) -> bool:
	return def.cook_profile != null and def.cook_profile.heat == heat


func can_receive(other: Item) -> bool:
	# Holding a clean plate over food: the food goes onto the plate instead.
	return false


func get_state() -> Dictionary:
	var d := super.get_state()
	if cook > 0.0:
		d["ck"] = snappedf(cook, 0.001)
	if chop > 0.0:
		d["ch"] = snappedf(chop, 0.01)
	if left >= 0:
		d["pl"] = left
	return d


func set_state(d: Dictionary) -> void:
	super.set_state(d)
	cook = d.get("ck", 0.0)
	chop = d.get("ch", 0.0)
	var pl := int(d.get("pl", -1))
	if pl != left:
		left = pl
		rebuild_visual()
	refresh_visual()
