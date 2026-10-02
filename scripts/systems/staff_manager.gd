class_name StaffManager
extends Node
## Hiring, firing and paying NPC employees.

var world: GameWorld


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld


func workers() -> Array:
	return world.all_of_kind(&"staff")


func hire(id: StringName) -> bool:
	var sd: StaffDef = Content.staff.get(id)
	if sd == null:
		return false
	if not world.economy.spend(sd.hire_cost, "Hire %s" % sd.display_name):
		return false
	var spawn := world.grid.street_point("staff_spawn", Vector2i(20, 4))
	var w: Worker = world.spawn_entity(&"staff", id, {"sd": String(id)}, {"pos": [spawn.x + 0.5, 0, spawn.y + 0.5], "yaw": 0.0})
	Events.notify("%s hired! Wage %s/day" % [sd.display_name, GameConst.money(sd.daily_wage)], &"info")
	if w:
		world.fx.sparkle(w.global_position + Vector3(0, 1.2, 0), Color("8fe39a"))
	return true


func dismiss(w: Worker) -> void:
	if w.held():
		var it := w.take_held()
		it.place_on_floor(w.global_position)
	world.despawn(w)


func pay_wages() -> void:
	var total := 0.0
	for w in workers():
		var sd: StaffDef = (w as Worker).staff_def
		if sd:
			total += sd.daily_wage
	if total > 0.0:
		world.economy.charge(total, "Staff wages")


func on_new_day() -> void:
	# Workers report to the back door each morning.
	var spawn := world.grid.street_point("staff_spawn", Vector2i(20, 4))
	for w in workers():
		(w as Worker).path.clear()
		(w as Worker).task = {}
		(w as Worker).global_position = GameConst.cell_center(spawn)


## Item interaction for workers walking up to a loose crate.
func save_data() -> Dictionary:
	return {}


func load_data(_d: Dictionary) -> void:
	pass
