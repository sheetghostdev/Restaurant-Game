class_name Worker
extends Entity
## An NPC employee. Workers follow simple, predictable routines and use the
## exact same interaction rules as players (they GRAB and USE fixtures), just
## more slowly. NPCs handle the repetitive work; players handle the chaos.

var staff_def: StaffDef
var role: StringName = &"dishwasher"
var work_speed := 0.6
var speed := 2.2
var hand: ItemSlot
var rig: CharacterRig
var facing := Vector3(0, 0, 1)
var path: Array[Vector3] = []
var task := {}
var _think := 0.0
var _anim := CharacterRig.Anim.IDLE
var _anim_t := 0.0
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _have := false
var _stuck := 0.0


func get_kind() -> StringName:
	return &"staff"


func _ready() -> void:
	add_to_group(&"actors")
	add_to_group(&"staff")
	rig = CharacterRig.new()
	add_child(rig)
	hand = ItemSlot.new()
	hand.position = Vector3(0, 0.8, 0.44)
	hand.owner_entity = self
	hand.index = 0
	add_child(hand)
	_build_look()


func _build_look() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = net_id * 31 + 7
	var app := CharacterRig.random_appearance(rng)
	var uniform := staff_def.uniform if staff_def else Color("8a9aa8")
	app["shirt"] = Color("e8e4dc")
	app["apron"] = uniform
	app["hat"] = &"cap"
	app["hat_color"] = uniform
	app["pants"] = Color("4a4f57")
	rig.build(app)


func setup(def: StaffDef) -> void:
	staff_def = def
	def_id = def.id
	role = def.role
	work_speed = def.work_speed
	speed = def.walk_speed
	if rig:
		_build_look()


# --- Actor interface ------------------------------------------------------------

func held() -> Item:
	return hand.item


func hold(it: Item) -> void:
	if it and hand.item == null:
		hand.put(it)


func take_held() -> Item:
	return hand.take()


func slot(i: int) -> ItemSlot:
	return hand if i == 0 else null


func facing_dir() -> Vector3:
	return facing


func actor_color() -> Color:
	return staff_def.uniform if staff_def else Color.GRAY


func play_action(anim: int, duration := 0.3) -> void:
	_anim = anim
	_anim_t = duration


func on_item_removed(_it: Item) -> void:
	pass


func display_name() -> String:
	return staff_def.display_name if staff_def else "Staff"


func status_text() -> String:
	return task.get("label", "Idle")


# --- Brain (authority) -----------------------------------------------------------

func server_tick(delta: float) -> void:
	if world == null:
		return
	if not path.is_empty():
		_walk(delta)
		return
	if task.is_empty():
		_think -= delta
		if _think <= 0.0:
			_think = 0.5
			task = StaffBrain.next_task(self)
			if not task.is_empty():
				_go(task)
		return
	_do_task(delta)


func _go(t: Dictionary) -> void:
	var f: Node3D = t.get("target")
	if f == null or not is_instance_valid(f):
		task = {}
		return
	var cell := StaffBrain.access_cell(world, f, global_position)
	if cell == Vector2i(-9999, -9999):
		task = {}
		_think = 2.0
		return
	path = world.grid.nav.find_path(global_position, cell)
	if path.is_empty() and GameConst.world_to_cell(global_position) != cell:
		task = {}
		_think = 2.0


func _walk(delta: float) -> void:
	var target := path[0]
	var to := target - global_position
	to.y = 0
	var dist := to.length()
	var step := speed * delta
	if dist <= step:
		global_position = Vector3(target.x, 0, target.z)
		path.remove_at(0)
		return
	var dir := to / dist
	global_position += dir * step
	facing = dir
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * 10.0, 0, 1))


func _do_task(delta: float) -> void:
	var f: Node3D = task.get("target")
	if f == null or not is_instance_valid(f):
		task = {}
		return
	var to := f.global_position - global_position
	to.y = 0
	if to.length() > 0.01:
		facing = to.normalized()
		rotation.y = atan2(facing.x, facing.z)
	var verb: int = task.get("verb", GameConst.Verb.GRAB)
	if f is Item:
		if f.global_position.distance_to(global_position) > 1.6:
			task = {}
			return
		if verb == GameConst.Verb.GRAB and not Interact.grab_item_query(self, f).is_empty():
			Interact.grab_item_perform(self, f)
		task = {}
		_think = 0.35
		return
	var q: Dictionary = f.interact_query(self, verb) if f.has_method("interact_query") else {}
	if q.is_empty() or q.get("blocked", false):
		task = {}
		_think = 0.6
		return
	if q.get("hold", false):
		f.interact_perform(self, verb, delta)
		if q.has("anim"):
			play_action(q["anim"], 0.25)
		_stuck += delta
		if _stuck > 25.0:
			task = {}
			_stuck = 0.0
		return
	f.interact_perform(self, verb, 0.0)
	if q.has("anim"):
		play_action(q["anim"], 0.4)
	task = {}
	_stuck = 0.0
	_think = 0.35


# --- Visuals -------------------------------------------------------------------

func _process(delta: float) -> void:
	if rig == null:
		return
	var moving := not path.is_empty()
	if not Net.is_authority() and _have:
		moving = global_position.distance_to(_target_pos) > 0.03
		global_position = global_position.lerp(_target_pos, clampf(delta * 10.0, 0, 1))
		rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 10.0, 0, 1))
	rig.speed = 0.5 if moving else 0.0
	rig.carrying = held() != null
	rig.heavy = held() != null and held().is_heavy()
	if _anim_t > 0.0:
		_anim_t -= delta
		rig.anim = _anim
	else:
		rig.anim = CharacterRig.Anim.WALK if moving else CharacterRig.Anim.IDLE


func get_motion() -> Array:
	return [snappedf(global_position.x, 0.01), snappedf(global_position.z, 0.01), snappedf(rotation.y, 0.02), _anim if _anim_t > 0.0 else -1]


func apply_motion(m: Array) -> void:
	_target_pos = Vector3(m[0], 0, m[1])
	_target_yaw = m[2]
	if not _have:
		global_position = _target_pos
	_have = true
	if m.size() > 3 and int(m[3]) >= 0:
		play_action(int(m[3]), 0.15)


func get_state() -> Dictionary:
	return {"sd": String(staff_def.id) if staff_def else String(def_id)}


func set_state(d: Dictionary) -> void:
	var sd: StaffDef = Content.staff.get(StringName(d.get("sd", String(def_id))))
	if sd:
		setup(sd)
