class_name ToolItem
extends Item
## Hand tools used directly (USE while holding): fire extinguisher and mop.
## The actual effect is resolved by the world (fires / messes in front of the
## actor) so tools stay simple.

var charge := 1.0   ## Extinguisher contents.


func tool_kind() -> StringName:
	return def.id


func display_name() -> String:
	if def.id == &"extinguisher":
		return "Fire Extinguisher (%d%%)" % roundi(charge * 100.0)
	return super.display_name()


func is_heavy() -> bool:
	return false


func get_state() -> Dictionary:
	var d := super.get_state()
	if charge < 1.0:
		d["q"] = snappedf(charge, 0.01)
	return d


func set_state(d: Dictionary) -> void:
	super.set_state(d)
	charge = d.get("q", 1.0)
