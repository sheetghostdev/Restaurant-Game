@tool
class_name ItemSlot
extends Marker3D
## A place that holds exactly one Item: a counter top, a grill plate, a shelf,
## a table setting or a player's hands. Items are reparented under their slot.

signal item_changed(slot: ItemSlot)

## If non-empty the item must have at least one of these tags (ItemDef.tags)
## or item classes (food/dish/crate/tool/package/trash).
@export var accept: PackedStringArray = []
@export var reject: PackedStringArray = []
@export var reject_heavy := false
@export var cold := false
@export var display_scale := 1.0

var index := -1
var owner_entity: Node3D
var item: Item
var locked := false   ## e.g. while a machine is running


func is_empty() -> bool:
	return item == null


func accepts_item(it: Item) -> bool:
	if it == null or locked:
		return false
	if reject_heavy and it.is_heavy():
		return false
	for r in reject:
		if it.matches(r):
			return false
	if accept.is_empty():
		return true
	for a in accept:
		if it.matches(a):
			return true
	return false


func can_hold(it: Item) -> bool:
	return item == null and accepts_item(it)


func put(it: Item) -> void:
	if it == null:
		return
	it.detach()
	item = it
	it.slot = self
	add_child(it)
	it.transform = Transform3D.IDENTITY
	it.scale = Vector3.ONE * display_scale
	it.on_slot_changed()
	item_changed.emit(self)


func take() -> Item:
	var it := item
	if it == null:
		return null
	it.detach()
	return it


## Called by Item.detach() when the item leaves.
func _release(it: Item) -> void:
	if item == it:
		item = null
		item_changed.emit(self)


func is_cold() -> bool:
	# Anything stored inside a cold room (walk-in cooler) stays fresh.
	if owner_entity is Fixture:
		var f := owner_entity as Fixture
		if f.world and not f.lifted and f.world.grid.is_cold_cell(f.cell):
			return true
	if not cold:
		return false
	if owner_entity and owner_entity.has_method("is_cooling"):
		return owner_entity.is_cooling()
	return true


func get_ref() -> Array:
	var oid: int = owner_entity.get("net_id") if owner_entity else 0
	return [oid, index]
