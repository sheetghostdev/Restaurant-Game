class_name Processor
extends FixtureComponent
## Turns an item into its prepared form through work (chopping). Manual
## processors need a player holding USE; automatic ones (the Auto-Chopper)
## work slowly on their own.

@export var slot_index := 0
@export var verb_label := "Chop"
@export var automatic := false
@export var auto_speed := 0.45
@export var blade_path: NodePath

var _sound_t := 0.0
var _blade: Node3D
var _visual_work := 0.0


func _ready() -> void:
	if not blade_path.is_empty():
		_blade = get_node_or_null(blade_path)


func work_item() -> FoodItem:
	var s := fixture.slot(slot_index)
	if s and s.item is FoodItem:
		var f := s.item as FoodItem
		if f.def.chop_into != &"" and not f.spoiled:
			return f
	return null


func query(actor: Node, verb: int) -> Dictionary:
	if verb != GameConst.Verb.USE or automatic:
		return {}
	var it := work_item()
	if it:
		return {"label": verb_label, "hold": true, "anim": CharacterRig.Anim.CHOP, "progress": it.chop / it.def.chop_work}
	var s := fixture.slot(slot_index)
	var held: Item = actor.held()
	if s.item == null and held is FoodItem and (held as FoodItem).def.chop_into != &"" and s.can_hold(held):
		return {"label": "Place & %s" % verb_label.to_lower()}
	return {}


func perform(actor: Node, verb: int, delta: float) -> bool:
	if verb != GameConst.Verb.USE:
		return false
	var s := fixture.slot(slot_index)
	var held: Item = actor.held()
	if s.item == null and held is FoodItem:
		s.put(actor.take_held())
		held.bump()
		held.mark_dirty()
		Audio.play_at(&"putdown", s.global_position)
		return true
	var speed: float = actor.get("work_speed") if actor.get("work_speed") != null else 1.0
	return work(delta * speed)


func work(amount: float) -> bool:
	var it := work_item()
	if it == null:
		return false
	it.chop += amount
	_sound_t -= amount
	if _sound_t <= 0.0:
		_sound_t = 0.24
		Audio.play_at(&"chop_%d" % randi_range(1, 3), fixture.global_position, -2.0, randf_range(0.92, 1.08))
		if world():
			world().fx.chop_bits(it.global_position + Vector3(0, 0.08, 0), it.def.color)
		it.bump()
	if it.chop >= it.def.chop_work:
		_finish(it)
	else:
		it.mark_dirty()
	return true


func _finish(it: FoodItem) -> void:
	var out_id := it.def.chop_into
	var w := world()
	w.despawn(it)
	var n := w.spawn_item(out_id, {}, {"slot": [fixture.net_id, slot_index]})
	if n:
		n.bump()
	Audio.play_at(&"pickup", fixture.global_position, -4.0, 1.2)
	w.stats_add(&"prepped", 1, out_id)


func server_tick(delta: float) -> void:
	if automatic and fixture.is_working() and work_item():
		work(delta * auto_speed)


func _process(delta: float) -> void:
	if _blade == null or fixture == null:
		return
	if work_item() and fixture.is_working():
		_visual_work += delta
		_blade.position.y = 0.12 + absf(sin(_visual_work * 9.0)) * 0.22
	else:
		_blade.position.y = lerpf(_blade.position.y, 0.34, clampf(delta * 6.0, 0, 1))


func status_text() -> String:
	var it := work_item()
	if it:
		return "%s %d%%" % [verb_label, roundi(100.0 * it.chop / it.def.chop_work)]
	return ""
