class_name Item
extends Entity
## A physical object that can be carried, placed in an ItemSlot or dropped on
## the floor. Subclasses add food, dishware, container and tool behaviour.

var def: ItemDef
var slot: ItemSlot = null
var visual: Node3D
var spoil_time := 0.0
var spoiled := false
var _floor_body: StaticBody3D
var _bump := 0.0


func get_kind() -> StringName:
	return &"item"


## Small things are drawn larger than life so they stay readable from the
## overhead camera (the miniature-diorama trick).
const READABLE_SCALE := {"food": 1.55, "dish": 1.4, "tool": 1.15}


func setup(d: ItemDef) -> void:
	def = d
	def_id = d.id
	name = "%s_%d" % [d.id, net_id]
	if visual == null:
		visual = Node3D.new()
		visual.name = "Visual"
		add_child(visual)
	rebuild_visual()


func visual_scale() -> float:
	return READABLE_SCALE.get(def.item_class, 1.0) if def else 1.0


func display_name() -> String:
	var n := def.display_name if def else "Item"
	return ("Spoiled " + n) if spoiled else n


func matches(tag: String) -> bool:
	if def == null:
		return false
	return def.item_class == tag or def.has_tag(tag) or String(def.id) == tag


func is_heavy() -> bool:
	return def != null and def.heavy


func can_pick_up(_actor: Node) -> bool:
	return true


# -----------------------------------------------------------------------------
# Visuals
# -----------------------------------------------------------------------------

func rebuild_visual() -> void:
	if visual == null:
		return
	for c in visual.get_children():
		visual.remove_child(c)
		c.queue_free()
	_build_model()
	visual.scale = Vector3.ONE * visual_scale()
	refresh_visual()


func _build_model() -> void:
	visual.add_child(Models.instance(def.model))


## Re-applies dynamic colouring without rebuilding meshes.
func refresh_visual() -> void:
	if spoiled:
		set_tint(Pal.SPOILED, 0.55)


func set_tint(color: Color, amount: float, node: Node = null) -> void:
	for mi in _mesh_instances(node if node else visual):
		mi.set_instance_shader_parameter(&"tint", Color(color.r, color.g, color.b, amount))


func set_mult(color: Color, node: Node) -> void:
	for mi in _mesh_instances(node):
		mi.set_instance_shader_parameter(&"mult", Vector3(color.r, color.g, color.b))


static func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root == null:
		return out
	if root is MeshInstance3D:
		out.push_back(root)
	for c in root.get_children():
		out.append_array(_mesh_instances(c))
	return out


func bump() -> void:
	_bump = 1.0
	set_process(true)


func _process(delta: float) -> void:
	if visual == null:
		set_process(false)
		return
	if _bump > 0.0:
		_bump = maxf(_bump - delta * 4.0, 0.0)
		var s := 1.0 + sin(_bump * PI) * 0.18
		visual.scale = Vector3(s, 2.0 - s, s) * visual_scale()
	else:
		visual.scale = Vector3.ONE * visual_scale()
		set_process(false)


# -----------------------------------------------------------------------------
# Location
# -----------------------------------------------------------------------------

## Removes the item from its slot / the floor. It is left without a parent.
func detach() -> void:
	if slot:
		var s := slot
		slot = null
		s._release(self)
	_set_floor_body(false)
	if get_parent():
		get_parent().remove_child(self)


func on_slot_changed() -> void:
	_set_floor_body(false)


func place_on_floor(pos: Vector3, yaw := 0.0) -> void:
	detach()
	world.items_root.add_child(self)
	position = Vector3(pos.x, 0.0, pos.z)
	rotation = Vector3(0, yaw, 0)
	scale = Vector3.ONE
	_set_floor_body(def.blocks_when_dropped)


func is_loose() -> bool:
	return slot == null and world != null and get_parent() == world.items_root


func is_cold() -> bool:
	return slot != null and slot.is_cold()


func holder() -> Node:
	return slot.owner_entity if slot else null


func _set_floor_body(on: bool) -> void:
	if on and _floor_body == null:
		_floor_body = StaticBody3D.new()
		_floor_body.collision_layer = GameConst.L_FLOOR_ITEM
		_floor_body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.62, 0.5, 0.5)
		cs.shape = sh
		cs.position.y = 0.25
		_floor_body.add_child(cs)
		add_child(_floor_body)
	elif not on and _floor_body:
		_floor_body.queue_free()
		_floor_body = null


func get_location() -> Dictionary:
	if slot:
		return {"slot": slot.get_ref()}
	if get_parent() and world and get_parent() == world.items_root:
		return {"floor": [position.x, position.y, position.z, rotation.y]}
	return {"none": true}


func set_location(d: Dictionary) -> void:
	if world:
		world.place_item(self, d)


# -----------------------------------------------------------------------------
# Combination API (overridden by subclasses)
# -----------------------------------------------------------------------------

## Can `other` be put into / onto this item?
func can_receive(_other: Item) -> bool:
	return false


func receive(_other: Item) -> void:
	pass


## Containers and piles can hand out one unit.
func can_take_one() -> bool:
	return false


func take_one() -> Item:
	return null


## USE verb directed at this item (when loose, or delegated by its holder).
func use_query(_actor: Node) -> Dictionary:
	return {}


func use_perform(_actor: Node, _delta: float) -> bool:
	return false


## Shown under the item name in targeting hints.
func status_text() -> String:
	return ""


# -----------------------------------------------------------------------------
# Freshness
# -----------------------------------------------------------------------------

func is_perishable() -> bool:
	return def != null and def.perishable and not spoiled


func server_tick(delta: float) -> void:
	if not is_perishable():
		return
	if is_cold():
		return
	spoil_time += delta
	if spoil_time >= def.spoil_seconds:
		spoil()


func spoil() -> void:
	if spoiled:
		return
	spoiled = true
	refresh_visual()
	mark_dirty()
	if world:
		world.on_item_spoiled(self)


func get_state() -> Dictionary:
	var d := {}
	if spoil_time > 0.0:
		d["sp"] = snappedf(spoil_time, 0.1)
	if spoiled:
		d["sd"] = true
	return d


func set_state(d: Dictionary) -> void:
	spoil_time = d.get("sp", 0.0)
	var was := spoiled
	spoiled = d.get("sd", false)
	if was != spoiled:
		rebuild_visual()
