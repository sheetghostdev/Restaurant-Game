class_name CrateItem
extends Item
## A delivered container of one ingredient. The units are visible inside, so
## anyone walking past a shelf can see "we're almost out of potatoes".
## Empty crates become clutter: stack them and leave them on the loading dock.

var supply_id: StringName
var content_id: StringName
var count := 0
var capacity := 10
var style := "crate"
var empties := 0          ## Extra empty crates stacked on top (when count == 0).

var _minis: Node3D
var _label: Node3D


func setup_supply(s: SupplyDef, units := -1) -> void:
	supply_id = s.id
	content_id = s.item_id
	capacity = s.quantity
	count = s.quantity if units < 0 else units
	style = s.container
	rebuild_visual()


func supply() -> SupplyDef:
	return Content.supply(supply_id)


func content_def() -> ItemDef:
	return Content.item(content_id)


func is_heavy() -> bool:
	return true


func is_empty_crate() -> bool:
	return count <= 0


func display_name() -> String:
	if count <= 0:
		return "Empty crates ×%d" % (empties + 1) if empties > 0 else "Empty crate"
	var cd := content_def()
	var n := cd.display_name if cd else "Supplies"
	if spoiled:
		n = "Spoiled " + n
	return "%s ×%d" % [n, count]


func status_text() -> String:
	if count <= 0:
		return "Leave on the loading dock"
	if spoiled:
		return "Spoiled!"
	var cd := content_def()
	if cd and cd.perishable and not is_cold():
		var left := cd.spoil_seconds - spoil_time
		if left < cd.spoil_seconds * 0.5:
			return "Warming up — refrigerate!"
		return "Keep cold"
	return ""


func is_perishable() -> bool:
	var cd := content_def()
	return cd != null and cd.perishable and count > 0 and not spoiled


func server_tick(delta: float) -> void:
	if not is_perishable() or is_cold():
		return
	spoil_time += delta
	var cd := content_def()
	if spoil_time >= cd.spoil_seconds:
		spoil()


# -----------------------------------------------------------------------------
# Units
# -----------------------------------------------------------------------------

func can_take_one() -> bool:
	return count > 0


func take_one() -> Item:
	if count <= 0:
		return null
	count -= 1
	var it: FoodItem = world.spawn_item(content_id, {}, {"none": true})
	if spoiled:
		it.spoiled = true
		it.refresh_visual()
	rebuild_visual()
	mark_dirty()
	world.stats_add(&"ingredients_used", 1, content_id)
	return it


func can_receive(other: Item) -> bool:
	if other is FoodItem:
		return count > 0 and other.def_id == content_id and other.is_untouched() and count < capacity and other.spoiled == spoiled
	if other is CrateItem:
		return count <= 0 and other.count <= 0 and empties + other.empties + 2 <= 5
	return false


func receive(other: Item) -> void:
	if other is FoodItem:
		count += 1
		world.stats_add(&"ingredients_used", -1, content_id)
	elif other is CrateItem:
		empties += other.empties + 1
	world.despawn(other)
	rebuild_visual()
	bump()
	mark_dirty()


func use_query(actor: Node) -> Dictionary:
	if count > 0 and actor.held() == null:
		var cd := content_def()
		return {"label": "Take %s" % (cd.display_name if cd else "one")}
	return {}


func use_perform(actor: Node, _delta: float) -> bool:
	if count <= 0 or actor.held() != null:
		return false
	var it := take_one()
	if it:
		actor.hold(it)
		Audio.play_at(&"crate_take", global_position)
		return true
	return false


# -----------------------------------------------------------------------------
# Visuals
# -----------------------------------------------------------------------------

func _build_model() -> void:
	var key := StringName(style)
	visual.add_child(Models.instance(key))
	for k in empties:
		var e := Models.instance(key)
		e.position = Vector3(0, 0.3 * (k + 1), 0)
		e.rotation.y = 0.08 * (k % 2)
		visual.add_child(e)
	_minis = Node3D.new()
	visual.add_child(_minis)
	var cd := content_def()
	if cd == null or count <= 0:
		return
	var info: Dictionary = ModelsProps.CONTAINER_INFO.get(key, ModelsProps.CONTAINER_INFO[&"crate"])
	var floor_y: float = info["floor"]
	var size: Vector2 = info["size"]
	var cols := 4
	var rows := 3
	var per_layer := cols * rows
	var unit := minf(size.x / cols, size.y / rows)
	var s := clampf(unit / 0.24, 0.45, 0.75)
	for k in count:
		var layer := k / per_layer
		var idx := k % per_layer
		var cx := idx % cols
		var cz := idx / cols
		var m := Models.instance(cd.model)
		m.position = Vector3(
			-size.x * 0.5 + (cx + 0.5) * size.x / cols,
			floor_y + layer * 0.07,
			-size.y * 0.5 + (cz + 0.5) * size.y / rows)
		m.rotation.y = float((k * 37) % 7) * 0.6
		m.scale = Vector3.ONE * s
		_minis.add_child(m)
	# Ingredient tag on the front face
	_label = Models.instance(&"crate_label")
	_label.position = Vector3(0, 0.2, 0.235)
	visual.add_child(_label)


func refresh_visual() -> void:
	var cd := content_def()
	if _label and cd:
		set_mult(cd.color, _label)
	if _minis:
		set_tint(Pal.SPOILED, 0.65 if spoiled else 0.0, _minis)
		if cd and cd.cook_profile:
			set_mult(cd.cook_profile.color_at(0.0), _minis)


func get_state() -> Dictionary:
	var d := super.get_state()
	d["su"] = String(supply_id)
	d["n"] = count
	if empties > 0:
		d["e"] = empties
	return d


func set_state(d: Dictionary) -> void:
	super.set_state(d)
	var s := Content.supply(StringName(d.get("su", "")))
	if s:
		supply_id = s.id
		content_id = s.item_id
		capacity = s.quantity
		style = s.container
	count = d.get("n", 0)
	empties = d.get("e", 0)
	rebuild_visual()
