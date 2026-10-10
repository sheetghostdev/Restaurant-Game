class_name Mixer
extends FixtureComponent
## A mixing bowl. GRAB puts ingredients in (flour, an egg...), then holding
## USE whisks them into whatever they make: flour + egg is a tray of muffin
## batter, ready for the oven. The finished tray waits in the bowl's slot for
## someone to GRAB it. Recipes are data: ItemDef.mixed_from.

@export var fill_path: NodePath

var added: Array[StringName] = []
var work := 0.0
var _fill: Node3D
var _fill_key := ""
var _clink := 0.0


func _ready() -> void:
	if not fill_path.is_empty():
		_fill = get_node_or_null(fill_path)


func _out() -> ItemSlot:
	return fixture.primary_slot()


## Every item that can be whisked from ingredients.
static func batches() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for d in Content.sorted_values(Content.items):
		if not (d as ItemDef).mixed_from.is_empty():
			out.push_back(d)
	return out


## What `ids` whisk into, if they are exactly some batch's ingredients.
static func result_for(ids: Array) -> ItemDef:
	for d in batches():
		if _same(d.mixed_from, ids):
			return d
	return null


## Could `id` go in alongside `ids` on the way to some batch?
static func fits(id: StringName, ids: Array) -> bool:
	var want := ids.duplicate()
	want.push_back(id)
	for d in batches():
		if _within(want, d.mixed_from):
			return true
	return false


static func _same(a: Array, b: Array) -> bool:
	return a.size() == b.size() and _within(b, a)


## Every element of `part` (with repeats) is in `whole`.
static func _within(part: Array, whole: Array) -> bool:
	var left := whole.duplicate()
	for x in part:
		var i := left.find(x)
		if i < 0:
			return false
		left.remove_at(i)
	return true


func _missing() -> Array:
	for d in batches():
		if _within(added, d.mixed_from):
			var left := d.mixed_from.duplicate()
			for x in added:
				left.erase(x)
			return left
	return []


func query(actor: Node, verb: int) -> Dictionary:
	var held: Item = actor.held()
	if verb == GameConst.Verb.GRAB:
		if held is FoodItem and _out().item == null:
			var f := held as FoodItem
			if fits(f.def_id, added):
				if f.spoiled:
					return {"label": "That %s has gone off" % f.def.display_name.to_lower(), "blocked": true}
				return {"label": "Add %s" % f.def.display_name.to_lower()}
		return {}
	if verb == GameConst.Verb.USE:
		if added.is_empty() or _out().item != null:
			return {}
		var r := result_for(added)
		if r:
			return {"label": "Whisk", "hold": true, "progress": work / maxf(r.mix_work, 0.1), "anim": "chop"}
		var need := _missing()
		var names := []
		for id in need:
			names.push_back(Content.display_name(id).to_lower())
		return {"label": "Needs %s" % " and ".join(names), "blocked": true}
	return {}


func perform(actor: Node, verb: int, delta: float) -> bool:
	if verb == GameConst.Verb.GRAB:
		var it: Item = actor.take_held()
		if it == null:
			return false
		added.push_back(it.def_id)
		world().despawn(it)
		work = 0.0
		Audio.play_at(&"crate_take", fixture.global_position, -2.0, 0.8)
		fixture.mark_dirty()
		return true
	var r := result_for(added)
	if r == null:
		return false
	work += delta
	_clink -= delta
	if _clink <= 0.0:
		_clink = 0.3
		Audio.play_at(&"dish_clink", fixture.global_position, -10.0, 1.5)
	if work >= r.mix_work:
		added.clear()
		work = 0.0
		world().spawn_item(r.id, {}, {"slot": [fixture.net_id, _out().index]})
		Audio.play_at(&"ding", fixture.global_position)
		world().fx.sparkle(fixture.global_position + Vector3(0, 1.0, 0), Color("f6e3a8"))
	fixture.mark_dirty()
	return true


func status_text() -> String:
	if _out().item:
		return "Ready: GRAB it"
	if added.is_empty():
		var lines := []
		for d in batches():
			var parts := []
			for id in d.mixed_from:
				parts.push_back(Content.display_name(id).to_lower())
			lines.push_back("%s → %s" % [" + ".join(parts), d.display_name.to_lower()])
		return " · ".join(lines)
	var have := []
	for id in added:
		have.push_back(Content.display_name(id).to_lower())
	var need := _missing()
	if need.is_empty():
		return "%s: hold USE to whisk" % " + ".join(have)
	var want := []
	for id in need:
		want.push_back(Content.display_name(id).to_lower())
	return "Has %s · add %s" % [" + ".join(have), " + ".join(want)]


func _process(_delta: float) -> void:
	if _fill == null or fixture == null:
		return
	# What's in the bowl: dry flour, then pale batter once it's being whisked.
	var key := "%d|%d" % [added.size(), int(work * 4.0)]
	if key == _fill_key:
		return
	_fill_key = key
	_fill.visible = not added.is_empty()
	if added.is_empty():
		return
	var flour := Color("f4efe4")
	var batter := Color("f2d98c")
	var t := clampf(work / 2.5, 0.0, 1.0) if result_for(added) else 0.0
	var c := flour.lerp(batter, t) if added.has(&"flour") else batter
	_fill.scale = Vector3(1, 0.5 + 0.5 * minf(added.size() / 2.0, 1.0), 1)
	_tint(c)


func _tint(c: Color) -> void:
	for mi in Item._mesh_instances(_fill):
		mi.set_instance_shader_parameter(&"mult", Vector3(c.r, c.g, c.b))


func get_state() -> Dictionary:
	if added.is_empty():
		return {}
	return {"a": added.map(func(x): return String(x)), "w": snappedf(work, 0.05)}


func set_state(d: Dictionary) -> void:
	added.clear()
	for x in d.get("a", []):
		added.push_back(StringName(x))
	work = float(d.get("w", 0.0))
