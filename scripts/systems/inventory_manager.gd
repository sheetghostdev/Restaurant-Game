class_name InventoryManager
extends Node
## Counts physical stock (units inside crates and loose whole ingredients) and
## raises low-stock alerts. The counts are informational — the real inventory
## is the crates themselves, visible on the shelves.

const LOW := 3

var world: GameWorld
var counts := {}          ## item id -> units
var warming := 0          ## perishable crates out of cold storage
var _t := 0.0
var _alerted := {}


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld


func refresh() -> void:
	if world == null:
		return
	var c := {}
	var warm := 0
	for it in world.items_in_world():
		if it is CrateItem:
			var cr := it as CrateItem
			if cr.count > 0 and not cr.spoiled:
				c[cr.content_id] = c.get(cr.content_id, 0) + cr.count
				if cr.is_perishable() and not cr.is_cold():
					warm += 1
		elif it is FoodItem:
			var f := it as FoodItem
			if f.is_untouched():
				c[f.def_id] = c.get(f.def_id, 0) + 1
	counts = c
	warming = warm
	_update_alerts()
	var out := {}
	for k in counts:
		out[String(k)] = counts[k]
	world.replicator.publish(&"inventory", {"c": out, "w": warming})


func apply_shared(d: Dictionary) -> void:
	counts.clear()
	var c: Dictionary = d.get("c", {})
	for k in c:
		counts[StringName(k)] = int(c[k])
	warming = d.get("w", 0)


## Ingredients the current menu depends on.
func tracked_ingredients() -> Array[StringName]:
	var out: Array[StringName] = []
	for s in Content.supplies.values():
		if not out.has(s.item_id):
			out.push_back(s.item_id)
	return out


func units(id: StringName) -> int:
	return counts.get(id, 0)


func _update_alerts() -> void:
	if world.day == null or world.day.phase != GameConst.Phase.SERVICE:
		for k in _alerted.keys():
			Events.alert.emit(StringName("low_" + String(k)), "", false)
		_alerted.clear()
		return
	for id in tracked_ingredients():
		var n := units(id)
		var key := StringName("low_" + String(id))
		var name := Content.display_name(id)
		if n <= 0:
			if _alerted.get(id, "") != "out":
				_alerted[id] = "out"
				Events.alert.emit(key, "OUT of %s!" % name.to_lower(), true)
				Audio.play_ui(&"error", -6.0)
		elif n <= LOW:
			if _alerted.get(id, "") != "low":
				_alerted[id] = "low"
				Events.alert.emit(key, "Low on %s (%d)" % [name.to_lower(), n], true)
		elif _alerted.has(id):
			_alerted.erase(id)
			Events.alert.emit(key, "", false)


func _physics_process(delta: float) -> void:
	if world == null or not Net.is_authority():
		return
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		refresh()
