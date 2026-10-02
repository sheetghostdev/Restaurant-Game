class_name Fixture
extends Entity
## Anything that sits on the restaurant grid: appliances, counters, tables,
## shelves, automation. A fixture is assembled from:
##   * a model (ProceduralModel children),
##   * ItemSlots (anywhere in its subtree),
##   * FixtureComponents (direct children) that add behaviour.
## Local +Z is the working face. rot 0 faces +Z (toward the camera).

signal state_changed

var def: FixtureDef
var cell := Vector2i.ZERO
var rot := 0
var slots: Array[ItemSlot] = []
var components: Array[FixtureComponent] = []
var lifted := false
var carrier_id := 0       ## net_id of the player carrying this (build mode)

var _body: StaticBody3D
var _bump := 0.0
var _model_root: Node3D


func get_kind() -> StringName:
	return &"fixture"


func setup(d: FixtureDef) -> void:
	def = d
	def_id = d.id


func _ready() -> void:
	_model_root = get_node_or_null("Model")
	_collect(self)
	for c in get_children():
		if c is FixtureComponent:
			components.push_back(c)
	if def and def.blocks_movement:
		_build_body()


func _collect(n: Node) -> void:
	for c in n.get_children():
		if c is ItemSlot:
			c.index = slots.size()
			c.owner_entity = self
			slots.push_back(c)
		if not (c is Item):
			_collect(c)


func _build_body() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = GameConst.L_FIXTURE
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	var h := def.collision_height if def else 0.8
	sh.size = Vector3(0.94, h, 0.94)
	cs.shape = sh
	cs.position = Vector3(0, h * 0.5, 0)
	_body.add_child(cs)
	add_child(_body)


func display_name() -> String:
	return def.display_name if def else "Fixture"


func place_at(c: Vector2i, r: int) -> void:
	cell = c
	rot = posmod(r, 4)
	position = GameConst.cell_center(cell)
	rotation = Vector3(0, rot * PI * 0.5, 0)


func front_dir() -> Vector2i:
	return GameConst.dir_from_rot(rot)


func front_cell() -> Vector2i:
	return cell + front_dir()


func back_cell() -> Vector2i:
	return cell - front_dir()


func front_vec() -> Vector3:
	var d := front_dir()
	return Vector3(d.x, 0, d.y)


func primary_slot() -> ItemSlot:
	return slots[0] if not slots.is_empty() else null


func slot(i: int) -> ItemSlot:
	return slots[i] if i >= 0 and i < slots.size() else null


## Point used by the targeting system.
func target_point() -> Vector3:
	return global_position


func get_component(type_name: String) -> FixtureComponent:
	for c in components:
		if c.get_script() and c.get_script().get_global_name() == type_name:
			return c
	return null


func is_working() -> bool:
	if def and def.powered and world and world.disasters and world.disasters.power_out:
		return false
	for c in components:
		if c.blocks_function():
			return false
	return true


## Cold storage: slots marked `cold` only cool while the fixture works.
func is_cooling() -> bool:
	return is_working() and not lifted


func is_blocked() -> bool:
	for c in components:
		if c.blocks_interaction():
			return true
	return false


# -----------------------------------------------------------------------------
# Interaction
# -----------------------------------------------------------------------------

func interact_query(actor: Node, verb: int) -> Dictionary:
	for c in components:
		if c.blocks_interaction():
			var r := c.query(actor, verb)
			return r
	for c in components:
		var r := c.query(actor, verb)
		if not r.is_empty():
			return r
	return _default_query(actor, verb)


func interact_perform(actor: Node, verb: int, delta: float) -> bool:
	for c in components:
		if c.blocks_interaction():
			if not c.query(actor, verb).is_empty():
				return c.perform(actor, verb, delta)
			return false
	for c in components:
		if not c.query(actor, verb).is_empty():
			var ok := c.perform(actor, verb, delta)
			if ok:
				bump()
			return ok
	var done := _default_perform(actor, verb, delta)
	if done and verb == GameConst.Verb.GRAB:
		bump()
	return done


func _default_query(actor: Node, verb: int) -> Dictionary:
	var s := primary_slot()
	if s == null:
		return {}
	if verb == GameConst.Verb.GRAB:
		return Interact.grab_slot_query(actor, s)
	if s.item:
		return s.item.use_query(actor)
	return {}


func _default_perform(actor: Node, verb: int, delta: float) -> bool:
	var s := primary_slot()
	if s == null:
		return false
	if verb == GameConst.Verb.GRAB:
		return Interact.grab_slot_perform(actor, s)
	if s.item:
		return s.item.use_perform(actor, delta)
	return false


func status_text() -> String:
	for c in components:
		var t := c.status_text()
		if t != "":
			return t
	return ""


# -----------------------------------------------------------------------------
# Simulation & state
# -----------------------------------------------------------------------------

func server_tick(delta: float) -> void:
	for c in components:
		c.server_tick(delta)


func get_state() -> Dictionary:
	var d := {}
	for c in components:
		var s := c.get_state()
		if not s.is_empty():
			d[String(c.name)] = s
	return d


func set_state(d: Dictionary) -> void:
	for c in components:
		var key := String(c.name)
		c.set_state(d.get(key, {}))
	state_changed.emit()


func get_location() -> Dictionary:
	var d := {"cell": [cell.x, cell.y], "rot": rot}
	if lifted and carrier_id != 0:
		d["carried"] = carrier_id
	return d


func set_location(d: Dictionary) -> void:
	if d.has("cell"):
		var c: Array = d["cell"]
		place_at(Vector2i(int(c[0]), int(c[1])), int(d.get("rot", 0)))
	# Clients mirror build-mode carrying.
	if world and not Net.is_authority() and is_inside_tree():
		var cid: int = d.get("carried", 0)
		if cid != 0 and not lifted:
			var p := world.get_entity(cid)
			if p:
				world.grid.vacate(self)
				set_lifted(true)
				carrier_id = cid
				get_parent().remove_child(self)
				p.add_child(self)
				position = Vector3(0, 0.55, 0.62)
				scale = Vector3.ONE * 0.75
				p.set("carried_fixture", self)
		elif cid == 0 and lifted:
			var holder := get_parent()
			if holder and holder.get("carried_fixture") == self:
				holder.set("carried_fixture", null)
			holder.remove_child(self)
			world.fixtures_root.add_child(self)
			scale = Vector3.ONE
			carrier_id = 0
			place_at(cell, rot)
			set_lifted(false)
			world.grid.occupy(self)
	if lifted and carrier_id != 0 and get_parent() and get_parent() is Node3D:
		rotation = Vector3(0, rot * PI * 0.5 - (get_parent() as Node3D).rotation.y, 0)


# -----------------------------------------------------------------------------
# Build mode
# -----------------------------------------------------------------------------

func set_lifted(on: bool) -> void:
	lifted = on
	if _body:
		_body.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
		_body.collision_layer = 0 if on else GameConst.L_FIXTURE
	for c in components:
		if on:
			c.on_lifted()
		else:
			c.on_placed()


func can_lift() -> bool:
	return not is_blocked()


# -----------------------------------------------------------------------------
# Feedback
# -----------------------------------------------------------------------------

func bump() -> void:
	_bump = 1.0
	set_process(true)


func _process(delta: float) -> void:
	if _model_root == null:
		set_process(false)
		return
	if _bump > 0.0:
		_bump = maxf(_bump - delta * 5.0, 0.0)
		var s := 1.0 + sin(_bump * PI) * 0.045
		_model_root.scale = Vector3(s, 2.0 - s, s)
	else:
		_model_root.scale = Vector3.ONE
		set_process(false)
