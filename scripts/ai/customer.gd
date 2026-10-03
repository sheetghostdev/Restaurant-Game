class_name Customer
extends Entity
## A single diner. Movement and visuals live here; decisions are made by the
## server-side CustomerGroup that owns this customer. Clients only receive
## position, animation, mood and the thought bubble.

var archetype: CustomerArchetype
var appearance := {}
var group: CustomerGroup          ## Server only.
var seat_table: Fixture           ## Server only.
var seat_side := -1
var path: Array[Vector3] = []
var speed := 1.6
var mood := 1.0
var anim := CharacterRig.Anim.IDLE
var bubble := ""                  ## "", "think", "order", "angry", "pay", "wait", or "r:<order codes,>"
var seated := false
var is_child := false
var orders: Array = []            ## Server: order dicts for this member
var menu_penalty := 0.0           ## Server: disappointment from crossed-off items
var eat_left := 0.0
var done_eating := false

var rig: CharacterRig
var _bubble_node: Node3D
var _bubble_key := "~"
var _want := 0                    ## local players' held dish fits this guest: 1 = recipe, 2 = exactly
var _want_t := 0.0
var _want_ring: Node3D
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _have_target := false
var _arrive_cb: Callable
var _face_yaw := 0.0
var _face_lock := false
var _steam_t := 0.0


func get_kind() -> StringName:
	return &"customer"


func _ready() -> void:
	add_to_group(&"actors")
	add_to_group(&"customers")
	rig = CharacterRig.new()
	add_child(rig)
	if not appearance.is_empty():
		rig.build(appearance)


func setup_look(app: Dictionary) -> void:
	appearance = app
	if rig:
		rig.build(app)


func held() -> Item:
	return null


# -----------------------------------------------------------------------------
# Movement (authority)
# -----------------------------------------------------------------------------

func walk_to_cell(cell: Vector2i, on_arrive: Callable = Callable()) -> bool:
	path = world.grid.nav.find_path(global_position, cell)
	_arrive_cb = on_arrive
	_face_lock = false
	seated = false
	if path.is_empty():
		if GameConst.world_to_cell(global_position) == cell:
			if on_arrive.is_valid():
				on_arrive.call()
			return true
		return false
	return true


func walk_to_point(p: Vector3, on_arrive: Callable = Callable()) -> void:
	path = [p]
	_arrive_cb = on_arrive
	_face_lock = false
	seated = false


func walk_path_to(p: Vector3, on_arrive: Callable = Callable()) -> void:
	path = world.grid.nav.find_path(global_position, GameConst.world_to_cell(p))
	if path.is_empty() or path[path.size() - 1].distance_to(p) > 0.05:
		path.push_back(p)
	_arrive_cb = on_arrive
	_face_lock = false
	seated = false


func is_walking() -> bool:
	return not path.is_empty()


func face(yaw: float) -> void:
	_face_yaw = yaw
	_face_lock = true


func server_tick(delta: float) -> void:
	if path.is_empty():
		if _face_lock:
			rotation.y = lerp_angle(rotation.y, _face_yaw, clampf(delta * 10.0, 0, 1))
		return
	var target := path[0]
	var to := target - global_position
	to.y = 0
	var dist := to.length()
	var step := speed * delta
	if dist <= step:
		global_position = Vector3(target.x, global_position.y, target.z)
		path.remove_at(0)
		if path.is_empty():
			var cb := _arrive_cb
			_arrive_cb = Callable()
			if cb.is_valid():
				cb.call()
		return
	var dir := to / dist
	global_position += dir * step
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * 10.0, 0, 1))


func sit_at(table: Fixture, side: int) -> void:
	seat_table = table
	seat_side = side
	var chair_cell: Vector2i = table.cell + SeatingTable.SIDES[side]
	var p := GameConst.cell_center(chair_cell)
	var to_table := (table.global_position - p).normalized()
	global_position = p - to_table * 0.05
	rotation.y = atan2(to_table.x, to_table.z)
	_face_yaw = rotation.y
	_face_lock = true
	seated = true
	mark_dirty()


# -----------------------------------------------------------------------------
# Visuals (all peers)
# -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if rig == null:
		return
	if not Net.is_authority() and _have_target:
		global_position = global_position.lerp(_target_pos, clampf(delta * 10.0, 0, 1))
		rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 10.0, 0, 1))
	var moving := is_walking() if Net.is_authority() else global_position.distance_to(_target_pos) > 0.03
	rig.speed = (speed / 4.5) * 1.6 if moving else 0.0
	rig.mood = mood
	rig.appearance["seated"] = seated
	if moving:
		rig.anim = CharacterRig.Anim.WALK
	else:
		rig.anim = anim
	position.y = 0.06 if seated else 0.0
	_update_bubble()
	_update_wanted(delta)
	if mood < 0.25 and fmod(Time.get_ticks_msec() * 0.001, 1.0) < delta * 2.0 and world:
		world.fx.steam(global_position + Vector3(0, 1.45, 0), 0.5, Color("ff8a6a"), true)


## When a local player carries a finished dish this guest is waiting for,
## light them up: green ring = exactly their order, yellow = right dish but
## different extras. The thought bubble pulses too.
func _update_wanted(delta: float) -> void:
	_want_t -= delta
	if _want_t <= 0.0:
		_want_t = 0.15
		_want = _held_match()
		if _want > 0 and _want_ring == null:
			_want_ring = Models.instance(&"ring")
			_want_ring.position = Vector3(0, 0.03, 0)
			_want_ring.scale = Vector3.ONE * 1.15
			add_child(_want_ring)
		if _want_ring:
			_want_ring.visible = _want > 0
			if _want > 0:
				var col := Pal.UI_GOOD if _want == 2 else Pal.UI_WARN
				for mi in Item._mesh_instances(_want_ring):
					mi.material_override = Models.mat_unshaded(col)
	if _bubble_node:
		var pulse := 1.0 + (0.18 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)) if _want > 0 else 0.0)
		_bubble_node.scale = Vector3.ONE * pulse


func _held_match() -> int:
	if not bubble.begins_with("r:") or world == null:
		return 0
	var best := 0
	for p in world.players():
		if not p.is_local():
			continue
		var d := p.held() as DishItem
		if d == null or not d.is_single() or d.dirty or d.contents.is_empty():
			continue
		for code in bubble.substr(2).split(",", false):
			var o := RecipeManager.parse_code(code)
			var r := Content.recipe(o["recipe"])
			if r and RecipeManager.satisfies(r, d):
				best = maxi(best, 2 if RecipeManager.is_exact(o, d) else 1)
	return best


func _update_bubble() -> void:
	if bubble == _bubble_key:
		if _bubble_node:
			_bubble_node.position.y = 1.75 + sin(Time.get_ticks_msec() * 0.004 + net_id) * 0.04
		return
	_bubble_key = bubble
	if _bubble_node:
		_bubble_node.queue_free()
		_bubble_node = null
	if bubble == "":
		return
	_bubble_node = ThoughtBubble.make(bubble)
	_bubble_node.position = Vector3(0, 1.75, 0)
	add_child(_bubble_node)


# -----------------------------------------------------------------------------
# Replication
# -----------------------------------------------------------------------------

func get_motion() -> Array:
	return [snappedf(global_position.x, 0.01), snappedf(global_position.z, 0.01), snappedf(rotation.y, 0.02)]


func apply_motion(m: Array) -> void:
	_target_pos = Vector3(m[0], position.y, m[1])
	_target_yaw = m[2]
	if not _have_target:
		global_position = _target_pos
		rotation.y = _target_yaw
	_have_target = true


func get_state() -> Dictionary:
	return {
		"a": String(archetype.id) if archetype else "",
		"app": _app_to_save(),
		"m": snappedf(mood, 0.05),
		"an": anim,
		"b": bubble,
		"s": seated,
	}


func set_state(d: Dictionary) -> void:
	archetype = Content.archetype(StringName(d.get("a", "")))
	if d.has("app") and appearance.is_empty():
		setup_look(_app_from_save(d["app"]))
	mood = d.get("m", mood)
	anim = d.get("an", anim)
	bubble = d.get("b", bubble)
	seated = d.get("s", seated)


func _app_to_save() -> Dictionary:
	var out := {}
	for k in appearance:
		var v = appearance[k]
		out[k] = v.to_html() if v is Color else (String(v) if v is StringName else v)
	return out


func _app_from_save(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v = d[k]
		if k in ["skin", "hair", "shirt", "pants", "shoes", "hat_color", "apron"] and v is String:
			out[k] = Color(v)
		elif k in ["hat", "hair_style", "accessory"]:
			out[k] = StringName(v)
		else:
			out[k] = v
	return out


func display_name() -> String:
	return archetype.display_name if archetype else "Customer"
