class_name FoodItem
extends Item
## An ingredient or prepared component. Tracks cooking and chopping progress.

var cook := 0.0
var chop := 0.0
var _model: Node3D


func _build_model() -> void:
	_model = Models.instance(def.model)
	visual.add_child(_model)


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
	return n


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
	return d


func set_state(d: Dictionary) -> void:
	super.set_state(d)
	cook = d.get("ck", 0.0)
	chop = d.get("ch", 0.0)
	refresh_visual()
