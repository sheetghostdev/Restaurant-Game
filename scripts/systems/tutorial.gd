class_name Tutorial
extends Node
## First-day guidance: short contextual tips that appear once, the first time
## each situation happens. Nothing is forced; the restaurant explains itself.

var world: GameWorld
var _shown := {}
var _t := 0.0


func _physics_process(delta: float) -> void:
	if world == null or world.day == null or not Net.is_authority() or world.day.day > 1:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	var phase := world.day.phase
	if phase == GameConst.Phase.MORNING:
		if _crates_on_dock() > 0:
			_tip(&"dock", "The delivery is on the dock! GRAB crates and carry them inside. Beef and lettuce go in the glass fridges — they spoil outside.")
		elif world.day.hour > 8.4:
			_tip(&"prep", "Prep ahead: USE a crate to take one ingredient, chop on a cutting board (hold USE). Prepped food doesn't keep overnight.")
		if world.day.hour > 9.0:
			_tip(&"open", "Ready? Hold USE on the OPEN sign by the front door to start service.")
	elif phase == GameConst.Phase.SERVICE:
		for g in world.customers.groups:
			if g.state == CustomerGroup.State.READY:
				_tip(&"order", "A table is waving at you! Walk up to it and press USE to take their order.")
			if g.state == CustomerGroup.State.WAITING_FOOD:
				_tip(&"serve", "Orders appear as cards at the top, one per table. Cook, put it on a plate, then GRAB the plate onto that table (look for the big number).")
		for f in world.grid.all_fixtures():
			var st := f.get_component("SeatingTable") as SeatingTable
			if st and st.has_dirty_dishes():
				_tip(&"dishes", "Dirty plates! GRAB them off the table and wash them in the sink (hold USE) — you only have so many plates.")
				break
		for f in world.grid.all_fixtures():
			var cook := f.get_component("Cooker") as Cooker
			if cook and cook.cooking_item() and cook.cooking_item().cook > 0.95:
				_tip(&"burn", "Watch the ring over the grill: green is perfect. Leave it too long and it burns — or catches fire.")
				break
	elif phase == GameConst.Phase.CLOSING:
		_tip(&"closing", "Closing time. Finish the last tables, then hold USE on the sign to end the day.")
	elif phase == GameConst.Phase.EVENING:
		_tip(&"evening", "Evening is for planning. The truck only brings what you order: use the manager's desk in storage to order tomorrow's supplies (tick Auto for things you want every day), buy equipment and hire help.")


func _crates_on_dock() -> int:
	var n := 0
	for it in world.items_root.get_children():
		if it is CrateItem and (it as CrateItem).count > 0:
			var rt := world.grid.room_type_at(GameConst.world_to_cell((it as CrateItem).global_position))
			if rt and rt.id == &"loading":
				n += 1
	return n


func _tip(id: StringName, text: String) -> void:
	if _shown.has(id):
		return
	_shown[id] = true
	Events.notify(text, &"tip")
	Audio.play_ui(&"ping", -6.0)
