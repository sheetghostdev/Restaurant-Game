class_name Interact
## The universal interaction language shared by players, NPC staff and
## automation. GRAB moves things; USE operates things.
##
## Query functions return a Dictionary describing the action that would happen
## ({"label": String, "hold": bool}) or an empty Dictionary if nothing applies.
## Perform functions are authority-only and return true if something happened.


static func grab_slot_query(actor: Node, slot: ItemSlot) -> Dictionary:
	if slot == null:
		return {}
	var held: Item = actor.held()
	var it := slot.item
	if held and it:
		if it.can_receive(held):
			return {"label": _combine_label(held, it)}
		if held.can_receive(it):
			return {"label": "Add %s" % it.display_name()}
		return {}
	if held:
		if slot.can_hold(held):
			return {"label": "Put down"}
		return {}
	if it and it.can_pick_up(actor):
		return {"label": "Pick up %s" % it.display_name()}
	return {}


static func grab_slot_perform(actor: Node, slot: ItemSlot) -> bool:
	if slot == null:
		return false
	var held: Item = actor.held()
	var it := slot.item
	if held and it:
		if it.can_receive(held):
			it.receive(held)
			Audio.play_at(&"putdown", it.global_position)
			return true
		if held.can_receive(it):
			held.receive(it)
			Audio.play_at(&"pickup", held.global_position)
			return true
		return false
	if held:
		if slot.can_hold(held):
			slot.put(actor.take_held())
			held.bump()
			held.mark_dirty()
			Audio.play_at(&"drop_heavy" if held.is_heavy() else &"putdown", slot.global_position)
			return true
		return false
	if it and it.can_pick_up(actor):
		actor.hold(slot.take())
		it.mark_dirty()
		Audio.play_at(&"pickup", slot.global_position)
		return true
	return false


## GRAB directed at a loose item on the floor.
static func grab_item_query(actor: Node, it: Item) -> Dictionary:
	var held: Item = actor.held()
	if held:
		if it.can_receive(held):
			return {"label": _combine_label(held, it)}
		if held.can_receive(it):
			return {"label": "Add %s" % it.display_name()}
		return {}
	if it.can_pick_up(actor):
		return {"label": "Pick up %s" % it.display_name()}
	return {}


static func grab_item_perform(actor: Node, it: Item) -> bool:
	var held: Item = actor.held()
	if held:
		if it.can_receive(held):
			it.receive(held)
			Audio.play_at(&"putdown", it.global_position)
			return true
		if held.can_receive(it):
			held.receive(it)
			Audio.play_at(&"pickup", held.global_position)
			return true
		return false
	if it.can_pick_up(actor):
		actor.hold(it)
		it.mark_dirty()
		Audio.play_at(&"drop_heavy" if it.is_heavy() else &"pickup", it.global_position)
		return true
	return false


static func use_item_query(actor: Node, it: Item) -> Dictionary:
	if it == null:
		return {}
	return it.use_query(actor)


static func _combine_label(held: Item, target: Item) -> String:
	if target is DishItem and held is FoodItem:
		return "Add to %s" % target.display_name()
	if target is DishItem and held is DishItem:
		return "Stack"
	if target is CrateItem and held is FoodItem:
		return "Put back"
	if target is CrateItem and held is CrateItem:
		return "Pour into crate" if (held as CrateItem).count > 0 else "Stack crates"
	return "Combine"
