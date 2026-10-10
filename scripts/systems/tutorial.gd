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
		var since := world.day.hour - world.day.morning_hour()
		_tip(&"format", "%s: %s" % [world.format.display_name, world.format.description])
		var mode := world.location.supply_mode
		if mode == "market" and since > 0.2:
			_tip(&"market", "No delivery truck on a train: the depot market is open on the platform. GRAB a stall to buy a crate. During service the train stops a few times — new stalls, new deals. Get back aboard before the whistle or your shopping stays on the platform!")
		elif mode == "grow" and since > 0.2:
			_tip(&"grow", "Nothing is delivered in orbit. Planters grow vegetables (USE to choose the crop, GRAB to harvest). The food printer prints everything else for credits (USE to choose, GRAB to take).")
		if _crates_on_dock() > 0:
			_tip(&"dock", "Your opening stock has arrived! GRAB crates and carry them to the shelves. Chilled crates go in the glass fridges — they spoil outside.")
		elif since > 0.4:
			_tip(&"prep", "Prep ahead: USE a crate to take one ingredient, chop on a cutting board (hold USE). Prepped food doesn't keep overnight.")
		if since > 1.0:
			_tip(&"open", "Ready? Hold USE on the OPEN sign to open now. Otherwise the doors open by themselves when the prep clock (top left) runs out, ready or not!")
	elif phase == GameConst.Phase.SERVICE:
		for g in world.customers.groups:
			if g.state == CustomerGroup.State.READY:
				_tip(&"order", "A table is waving at you! Walk up to it and press USE to take their order.")
			if g.state == CustomerGroup.State.WAITING_FOOD:
				_tip(&"serve", "Orders appear as paper tickets at the top, one per table: the colour is the tablecloth, the pictures show exactly what goes on the plate. Cook it, plate it, then GRAB the plate onto that table.")
		for f in world.grid.all_fixtures():
			var st := f.get_component("SeatingTable") as SeatingTable
			if st and st.has_dirty_dishes():
				_tip(&"dishes", "Dirty plates! GRAB them off the table and wash them in the sink (hold USE) — you only have so many plates.")
				break
		for f in world.grid.all_fixtures():
			var cook := f.get_component("Cooker") as Cooker
			if cook and cook.cook_progress() > 0.95:
				_tip(&"burn", "Watch the ring over the %s: green is perfect. Leave it too long and it burns — or catches fire." % f.def.display_name.to_lower())
				break
	elif phase == GameConst.Phase.CLOSING:
		_tip(&"closing", "Closing time: no new guests. Finish the last tables; the day ends when they've gone.")
	elif phase == GameConst.Phase.EVENING:
		if world.location.supply_mode == "truck":
			_tip(&"evening", "Evening is for planning. The truck only brings what you order: use the manager's desk in storage to order tomorrow's supplies (tick Auto for things you want every day), buy equipment and hire help.")
		else:
			_tip(&"evening", "Evening is for planning: buy equipment and hire help at the manager's desk.")


func _crates_on_dock() -> int:
	var n := 0
	for it in world.items_root.get_children():
		if it is CrateItem and (it as CrateItem).count > 0:
			var c := GameConst.world_to_cell((it as CrateItem).global_position)
			var rt := world.grid.room_type_at(c)
			if (rt and rt.id == &"loading") or c in world.grid.delivery_zone:
				n += 1
	return n


func _tip(id: StringName, text: String) -> void:
	if _shown.has(id):
		return
	_shown[id] = true
	Events.notify(text, &"tip")
	Audio.play_ui(&"ping", -6.0)
