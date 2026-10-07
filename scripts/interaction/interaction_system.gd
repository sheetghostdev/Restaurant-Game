class_name InteractionSystem
extends Node
## Resolves what each player is targeting and turns button presses into
## interactions. Targeting is deliberately forgiving: anything within reach in
## front of the player is a candidate, and candidates that can actually accept
## the player's current action win ties.
##
## Runs for every player on the authority. On clients it only computes targets
## for local players (for highlights and hints) and forwards button edges to
## the server.

const REACH := 1.5
const PROBE := 0.72
const LIFT_TIME := 0.4

var world: GameWorld
var _targets := {}        ## player -> Node
var _hints := {}          ## player -> Dictionary
var _highlighted := {}    ## Node -> Color
var _use_target := {}     ## player -> Node (current hold-USE target)
var _lift_started := {}   ## player -> bool
var _press_took := {}     ## player -> {item, slot}: what this GRAB press picked up off a fixture
var _last_pos := {}       ## player -> position last physics frame (stack wobble)

## Chance per second of a tall dirty pile toppling while walking, times the
## square of how many dishes it holds over DishItem.SAFE_STACK.
const TOPPLE_RATE := 0.006


func _ready() -> void:
	world = owner as GameWorld if owner is GameWorld else get_parent().get_parent() as GameWorld


func target_of(p: Node) -> Node:
	var t = _targets.get(p)
	return t if is_instance_valid(t) else null


func hint_for(p: Node) -> Dictionary:
	return _hints.get(p, {})


func _physics_process(delta: float) -> void:
	if world == null or world.grid == null:
		return
	var auth := Net.is_authority()
	var wanted := {}
	for p in world.players():
		if not auth and not p.is_local():
			continue
		var t := find_target(p)
		_targets[p] = t
		if auth:
			_process_actions(p, t, delta)
			_check_stack(p, delta)
		else:
			Net.send_buttons(p)
		_hints[p] = _build_hint(p, t)
		p.grab_pressed = false
		p.use_pressed = false
		p.alt_pressed = false
		p.grab_released = false
		if p.is_local() and t:
			wanted[t] = p.actor_color()
	_update_highlights(wanted)


# -----------------------------------------------------------------------------
# Targeting
# -----------------------------------------------------------------------------

func find_target(p: Node) -> Node:
	var pos: Vector3 = p.global_position
	var fwd: Vector3 = p.facing_dir()
	var probe := pos + fwd * PROBE
	var held: Item = p.held()
	var best: Node = null
	var best_score := INF
	for cand in _candidates(p, pos):
		var tp: Vector3 = _target_point(cand)
		var to := Vector3(tp.x - pos.x, 0, tp.z - pos.z)
		var dist := to.length()
		if dist > REACH + (0.35 if cand is Fixture else 0.0):
			continue
		if dist > 0.25 and fwd.dot(to / dist) < -0.05:
			continue
		# No reaching through walls to whatever is on the other side.
		if world.grid.line_crosses_wall(pos, _reach_point(cand, pos)):
			continue
		var score := Vector2(tp.x - probe.x, tp.z - probe.z).length()
		var g := _query(cand, p, GameConst.Verb.GRAB)
		var u := _query(cand, p, GameConst.Verb.USE)
		if g.is_empty() and u.is_empty():
			score += 0.9
		elif held and not g.is_empty():
			score -= 0.25
		if cand is Item:
			score -= 0.12   # small things on the floor are easy to miss
		if score < best_score:
			best_score = score
			best = cand
	return best


func _candidates(p: Node, pos: Vector3) -> Array:
	var out := []
	var c := GameConst.world_to_cell(pos)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var f := world.grid.fixture_at(c + Vector2i(dx, dz))
			if f and not f.lifted:
				out.push_back(f)
	for it in world.items_root.get_children():
		if it is Item and (it as Item).global_position.distance_squared_to(pos) < 4.0:
			out.push_back(it)
	for n in get_tree().get_nodes_in_group(&"interactables"):
		if n is Node3D and (n as Node3D).global_position.distance_squared_to(pos) < 6.0:
			out.push_back(n)
	return out


## Walking with a tall dirty pile: the higher it is, the likelier it falls.
func _check_stack(p: PlayerCharacter, delta: float) -> void:
	var last: Vector3 = _last_pos.get(p, p.global_position)
	_last_pos[p] = p.global_position
	var pile := p.held() as DishItem
	if pile == null or pile.topple_risk() <= 0.0 or delta <= 0.0:
		return
	var speed := Vector2(p.global_position.x - last.x, p.global_position.z - last.z).length() / delta
	if speed < 0.6:
		return
	var over := pile.count() - DishItem.SAFE_STACK
	var rate := TOPPLE_RATE * over * over * (2.0 if speed > PlayerCharacter.WALK_SPEED + 0.5 else 1.0)
	if randf() < rate * delta:
		world.disasters.topple_dishes(p, pile)


## The point of a candidate the player's hand has to reach: for a fixture the
## middle of the side facing the player, so a counter set against a wall is
## still reachable from its own room.
func _reach_point(n: Node, from: Vector3) -> Vector3:
	var tp := _target_point(n)
	if n is Fixture:
		var to := Vector3(from.x - tp.x, 0, from.z - tp.z)
		if to.length() > 0.001:
			tp += to.normalized() * 0.4
	return tp


func _target_point(n: Node) -> Vector3:
	if n.has_method("target_point"):
		return n.target_point()
	return (n as Node3D).global_position


func _query(t: Node, p: Node, verb: int) -> Dictionary:
	if t == null or not is_instance_valid(t):
		return {}
	if t is Item:
		if verb == GameConst.Verb.GRAB:
			return Interact.grab_item_query(p, t)
		return (t as Item).use_query(p)
	if t.has_method("interact_query"):
		return t.interact_query(p, verb)
	return {}


# -----------------------------------------------------------------------------
# Actions (authority)
# -----------------------------------------------------------------------------

func _process_actions(p: PlayerCharacter, t: Node, delta: float) -> void:
	var held := p.held()
	var calm := world.is_calm()
	# --- Carrying a fixture (build mode) ---
	if p.carried_fixture:
		if p.alt_pressed:
			world.build.rotate_carried(p)
		if p.grab_pressed:
			world.build.try_place_carried(p)
		return
	# --- GRAB ---
	if p.in_grab:
		p.grab_hold_time += delta
	if p.grab_pressed:
		p.grab_hold_time = 0.0
		_lift_started[p] = false
		_press_took.erase(p)
		var gq := _query(t, p, GameConst.Verb.GRAB) if t else {}
		if held is PackageItem and calm and world.build.try_unpack(p):
			pass
		elif gq.get("blocked", false):
			# The hint already explains why ("Dishwasher is full"): refuse.
			_refuse(p, t)
		elif not gq.is_empty():
			var from := _slot_map(t)
			_perform(t, p, GameConst.Verb.GRAB, 0.0)
			if held == null and p.held() and from.has(p.held()):
				_press_took[p] = {"item": p.held(), "slot": from[p.held()], "fixture": t}
		elif held:
			# Facing a station that refuses the item: give feedback instead of
			# dumping it on the floor by accident.
			if t is Fixture and _facing_directly(p, t):
				_refuse(p, t)
			else:
				_drop(p)
		elif calm and t is Fixture and (t as Fixture).can_lift():
			# Prep or evening, empty hands, nothing to take: pick it straight up.
			_lift_started[p] = true
			world.build.try_lift(p, t)
	if p.in_grab and calm and not _lift_started.get(p, false) and p.grab_hold_time >= LIFT_TIME and t is Fixture:
		# Holding GRAB moves the furniture, along with whatever is on it: if
		# the press picked something up off it, that goes back first.
		var took: Dictionary = _press_took.get(p, {})
		if held == null or (not took.is_empty() and took["item"] == held and took["fixture"] == t):
			_lift_started[p] = true
			if held:
				var slot: ItemSlot = took["slot"]
				if slot.can_hold(held):
					slot.put(p.take_held())
			if p.held() == null:
				world.build.try_lift(p, t)
	if not p.in_grab:
		p.grab_hold_time = 0.0
	# --- USE ---
	if held is ToolItem and p.in_use:
		world.disasters.use_tool(p, held, delta)
	elif (p.in_use or p.use_pressed) and t:
		# use_pressed is checked too: a remote tap's press and release can
		# land in the same server frame.
		var q := _query(t, p, GameConst.Verb.USE)
		if q.get("blocked", false):
			if p.use_pressed:
				_refuse(p, t)
		elif not q.is_empty():
			if q.get("hold", false):
				if _use_target.get(p) != t:
					_use_target[p] = t
				_perform(t, p, GameConst.Verb.USE, delta)
				if q.has("anim"):
					p.play_action(q["anim"], 0.2)
			elif p.use_pressed:
				_perform(t, p, GameConst.Verb.USE, 0.0)
				if q.has("anim"):
					p.play_action(q["anim"], 0.35)
		elif p.use_pressed:
			Audio.play_at(&"error", p.global_position, -8.0)
	if not p.in_use:
		_use_target.erase(p)
	# --- ALT: ping ---
	if p.alt_pressed:
		var at: Vector3 = _target_point(t) if t else p.global_position + p.facing_dir() * 1.0
		world.fx.ping(at, p.actor_color())


## item -> slot for everything sitting on a fixture.
func _slot_map(t: Node) -> Dictionary:
	var out := {}
	if t is Fixture:
		for sl in (t as Fixture).slots:
			if sl.item:
				out[sl.item] = sl
	return out


func _perform(t: Node, p: Node, verb: int, delta: float) -> bool:
	if t is Item:
		if verb == GameConst.Verb.GRAB:
			return Interact.grab_item_perform(p, t)
		return (t as Item).use_perform(p, delta)
	if t.has_method("interact_perform"):
		return t.interact_perform(p, verb, delta)
	return false


func _facing_directly(p: Node, t: Node3D) -> bool:
	var to: Vector3 = t.global_position - (p as Node3D).global_position
	to.y = 0
	return to.length() < 1.15 and p.facing_dir().dot(to.normalized()) > 0.6


## Drops the held item in front of the player if there's room.
## Feedback for an action the target won't take right now.
func _refuse(p: PlayerCharacter, t: Node) -> void:
	Audio.play_at(&"error", p.global_position, -8.0)
	if t is Fixture:
		(t as Fixture).bump()


func _drop(p: PlayerCharacter) -> bool:
	var it := p.held()
	if it == null:
		return false
	var spot := find_drop_spot(p.global_position, p.facing_dir(), it.is_heavy())
	if spot == Vector3.INF:
		Audio.play_at(&"error", p.global_position, -8.0)
		return false
	p.take_held()
	it.place_on_floor(spot, p.rotation.y)
	it.bump()
	it.mark_dirty()
	Audio.play_at(&"drop_heavy" if it.is_heavy() else &"putdown", spot)
	return true


func find_drop_spot(pos: Vector3, fwd: Vector3, heavy: bool) -> Vector3:
	var tries := [fwd * 0.75, fwd * 0.75 + fwd.cross(Vector3.UP) * 0.45, fwd * 0.75 - fwd.cross(Vector3.UP) * 0.45, fwd * 0.4]
	if not heavy:
		tries.push_back(Vector3.ZERO)
	for off in tries:
		var spot: Vector3 = pos + off
		var c := GameConst.world_to_cell(spot)
		if not world.grid.walkable(c):
			continue
		var pc := GameConst.world_to_cell(pos)
		if c != pc and world.grid.wall_between(pc, c):
			continue
		if heavy:
			spot = Vector3(clampf(spot.x, c.x + 0.32, c.x + 0.68), 0, clampf(spot.z, c.y + 0.27, c.y + 0.73))
			# Never drop a solid box on top of whoever is standing there.
			if spot.distance_to(Vector3(pos.x, 0, pos.z)) < 0.62:
				continue
			var blocked := false
			for a in get_tree().get_nodes_in_group(&"players"):
				var ap := (a as Node3D).global_position
				if Vector2(ap.x - spot.x, ap.z - spot.z).length() < 0.55:
					blocked = true
			if blocked:
				continue
		var clear := true
		for other in world.items_root.get_children():
			if other is Item and (other as Item).global_position.distance_to(spot) < (0.55 if heavy else 0.28):
				clear = false
				break
		if clear:
			return spot
	return Vector3.INF


# -----------------------------------------------------------------------------
# Hints & highlights (local)
# -----------------------------------------------------------------------------

func _build_hint(p: Node, t: Node) -> Dictionary:
	var h := {"target": t}
	if p.carried_fixture:
		h["grab"] = "Place"
		h["alt"] = "Rotate"
		return h
	var held: Item = p.held()
	if held is ToolItem:
		h["use"] = "Spray" if held.def_id == &"extinguisher" else "Mop"
	if t:
		var g := _query(t, p, GameConst.Verb.GRAB)
		var u := _query(t, p, GameConst.Verb.USE)
		if not g.is_empty() and g.get("label", "") != "":
			h["grab"] = g.get("label", "")
		if not u.is_empty() and not h.has("use"):
			h["use"] = u.get("label", "")
			if u.has("progress"):
				h["progress"] = u["progress"]
		h["name"] = t.display_name() if t.has_method("display_name") else ""
		if t.has_method("status_text"):
			h["status"] = t.status_text()
		if t is Fixture and world.is_calm() and held == null and (t as Fixture).can_lift():
			if g.is_empty():
				h["grab"] = "Move"   # nothing to take: one press picks it up
			else:
				h["lift"] = true
				if p.in_grab and p.grab_hold_time > 0.05:
					h["lift_progress"] = clampf(p.grab_hold_time / LIFT_TIME, 0.0, 1.0)
		elif t is Fixture and world.is_calm() and not _press_took.get(p, {}).is_empty() and p.in_grab and _press_took[p]["fixture"] == t:
			h["lift_progress"] = clampf(p.grab_hold_time / LIFT_TIME, 0.0, 1.0)
	if held and not h.has("grab"):
		h["grab"] = "Drop"
	if held is PackageItem and world.is_calm():
		h["grab"] = "Unpack here"
	return h


func _update_highlights(wanted: Dictionary) -> void:
	for n in _highlighted.keys():
		if not is_instance_valid(n):
			_highlighted.erase(n)
			continue
		if not wanted.has(n) or wanted[n] != _highlighted[n]:
			_set_overlay(n, null)
			_highlighted.erase(n)
	for n in wanted:
		if not _highlighted.has(n):
			_set_overlay(n, Models.mat_highlight(wanted[n]))
			_highlighted[n] = wanted[n]


func _set_overlay(root: Node, mat: Material) -> void:
	if root is GeometryInstance3D and not (root is Label3D):
		(root as GeometryInstance3D).material_overlay = mat
	for c in root.get_children():
		if c is PlayerCharacter:
			continue
		_set_overlay(c, mat)
