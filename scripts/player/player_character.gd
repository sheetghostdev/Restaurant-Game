class_name PlayerCharacter
extends CharacterBody3D
## A player-controlled restaurant worker.
##
## Movement is tuned for responsiveness over realism: fast (not instant)
## acceleration, snappy deceleration, quick turning, a slight weight when
## hauling heavy things, and soft separation instead of hard player-player
## collision so nobody gets stuck in a doorway.
##
## Implements the Entity interface (net_id, get_state, ...) and the Actor
## interface used by the interaction system (held/hold/take_held/hand).

signal held_changed

const WALK_SPEED := 4.5
const SPRINT_SPEED := 6.4
const ACCEL := 34.0
const DECEL := 46.0
const TURN_SPEED := 17.0
const HEAVY_FACTOR := 0.8
const FIXTURE_FACTOR := 0.72
const SEPARATION_RADIUS := 0.62

var net_id := 0
var def_id: StringName = &"player"
var world: GameWorld
var player_index := 0
var peer_id := 1
var device := -1
var player_name := "Chef"

# Input state. Local devices fill these each frame; remote players get them
# from the network. Edge flags are consumed by the InteractionSystem.
var input_move := Vector2.ZERO
var in_grab := false
var in_use := false
var in_alt := false
var in_sprint := false
var grab_pressed := false
var use_pressed := false
var alt_pressed := false
var grab_released := false
var grab_hold_time := 0.0

var facing := Vector3(0, 0, 1)
var carried_fixture: Fixture
var action_anim := -1
var _action_timer := 0.0
var _step_dist := 0.0
var _remote_target := Vector3.ZERO
var _remote_yaw := 0.0
var _has_remote := false
var _sprint_fx := 0.0

@onready var rig: CharacterRig = $Rig
@onready var hand: ItemSlot = $Hand
@onready var ring: MeshInstance3D = $Ring
@onready var tag: Label3D = $NameTag


func get_kind() -> StringName:
	return &"player"


func _ready() -> void:
	add_to_group(&"actors")
	add_to_group(&"players")
	hand.owner_entity = self
	hand.index = 0
	_build_look()


func _build_look() -> void:
	rig.build(appearance_for(player_index))
	var col := actor_color()
	ring.mesh = Models.mesh(&"ring")
	ring.material_override = Models.mat_unshaded(Color(col.r, col.g, col.b, 0.85), true)
	tag.text = player_name
	tag.modulate = col
	tag.font = load("res://art/fonts/Rubik-Bold.ttf")


static func appearance_for(index: int) -> Dictionary:
	var col := Pal.player_color(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (index + 3)
	var hats := [&"chef", &"cap", &"bandana", &"beanie", &"chef", &"cap"]
	var styles := [&"short", &"bun", &"spiky", &"long", &"pony", &"curly"]
	var app := {
		"skin": Pal.SKIN_TONES[(index * 2 + 1) % Pal.SKIN_TONES.size()],
		"hair": Pal.HAIR_COLORS[(index * 3) % 5],
		"hair_style": styles[index % styles.size()],
		"shirt": Color("f4f1ea"),
		"pants": Color("3d4147"),
		"shoes": col.darkened(0.15),
		"apron": col,
		"hat": hats[index % hats.size()],
		"hat_color": col,
		"glasses": index == 3,
		"mustache": index == 4,
		"accessory": &"bowtie" if index == 5 else &"",
	}
	if app["hat"] == &"chef":
		app["hat_color"] = col
	return app


# -----------------------------------------------------------------------------
# Actor interface
# -----------------------------------------------------------------------------

func held() -> Item:
	return hand.item


func hold(it: Item) -> void:
	if it == null:
		return
	if hand.item and hand.item != it:
		push_warning("Player already holding something")
		return
	hand.put(it)
	rig.squash(0.6)
	held_changed.emit()


func take_held() -> Item:
	var it := hand.take()
	held_changed.emit()
	return it


func on_item_removed(_it: Item) -> void:
	held_changed.emit()


func slot(i: int) -> ItemSlot:
	return hand if i == 0 else null


func actor_color() -> Color:
	return Pal.player_color(player_index)


func facing_dir() -> Vector3:
	return facing


func is_player() -> bool:
	return true


func play_action(anim: int, duration := 0.3) -> void:
	action_anim = anim
	_action_timer = duration


func is_local() -> bool:
	return device >= 0 and peer_id == Net.my_id()


func display_name() -> String:
	return player_name


# -----------------------------------------------------------------------------
# Update
# -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_local():
		_read_local_input()
		_move(delta)
		if not Net.is_authority():
			Net.send_player_state(self)
	elif _has_remote:
		# Remote player: ease toward the latest network position.
		global_position = global_position.lerp(_remote_target, clampf(delta * 14.0, 0, 1))
		rotation.y = lerp_angle(rotation.y, _remote_yaw, clampf(delta * 14.0, 0, 1))
		facing = Vector3(sin(rotation.y), 0, cos(rotation.y))
	position.y = 0.0
	_update_anim(delta)


func _read_local_input() -> void:
	if world and world.input_blocked(self):
		set_input(Vector2.ZERO, false, false, false, false)
		return
	var s := Inputs.read(device)
	set_input(s["move"], s["grab"], s["use"], s["alt"], s["sprint"])


## Applies an input snapshot and computes press/release edges.
func set_input(move: Vector2, grab: bool, use: bool, alt: bool, sprint: bool) -> void:
	input_move = move
	if grab and not in_grab:
		grab_pressed = true
	if not grab and in_grab:
		grab_released = true
	if use and not in_use:
		use_pressed = true
	if alt and not in_alt:
		alt_pressed = true
	in_grab = grab
	in_use = use
	in_alt = alt
	in_sprint = sprint


func _move(delta: float) -> void:
	var mv := input_move
	var speed := SPRINT_SPEED if in_sprint else WALK_SPEED
	if carried_fixture:
		speed *= FIXTURE_FACTOR
	elif held() and held().is_heavy():
		speed *= HEAVY_FACTOR
	var target := Vector3(mv.x, 0, mv.y) * speed
	var accel := ACCEL
	var decel := DECEL
	var slippery := world != null and world.disasters != null and world.disasters.is_slippery(global_position)
	if slippery:
		accel *= 0.22
		decel *= 0.08
	var horiz := Vector3(velocity.x, 0, velocity.z)
	if target.length() > 0.01:
		# Turning sharply should not feel like steering a boat: bleed off the
		# sideways component quickly.
		var along := horiz.project(target.normalized()) if horiz.length() > 0.01 else Vector3.ZERO
		var side := horiz - along
		side = side.move_toward(Vector3.ZERO, decel * delta * 1.4)
		horiz = (along + side).move_toward(target, accel * delta)
	else:
		horiz = horiz.move_toward(Vector3.ZERO, decel * delta)
	velocity = Vector3(horiz.x, 0, horiz.z) + _separation()
	move_and_slide()
	velocity = Vector3(horiz.x, 0, horiz.z)
	if mv.length() > 0.12:
		var want := atan2(mv.x, mv.y)
		var diff := absf(angle_difference(rotation.y, want))
		var k := TURN_SPEED * delta * (1.6 if diff > 2.2 else 1.0)
		rotation.y = lerp_angle(rotation.y, want, clampf(k, 0.0, 1.0))
	facing = Vector3(sin(rotation.y), 0, cos(rotation.y))
	# Footsteps & sprint puffs
	var moved := horiz.length() * delta
	_step_dist += moved
	if _step_dist > (0.75 if in_sprint else 0.55):
		_step_dist = 0.0
		Audio.play_at(&"footstep_%d" % randi_range(1, 3), global_position, -14.0, randf_range(0.9, 1.1))
		if in_sprint and world and world.fx and horiz.length() > 5.0:
			world.fx.dust(global_position)


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for a in get_tree().get_nodes_in_group(&"actors"):
		if a == self:
			continue
		var n := a as Node3D
		var d := global_position - n.global_position
		d.y = 0
		var dist := d.length()
		if dist < SEPARATION_RADIUS and dist > 0.001:
			var strength := 7.0 if a is PlayerCharacter else 4.0
			push += d / dist * (SEPARATION_RADIUS - dist) * strength
	return push


func _update_anim(delta: float) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	if not is_local() and _has_remote:
		hv = (_remote_target - global_position) * 10.0
	rig.speed = clampf(hv.length() / WALK_SPEED, 0.0, 1.4)
	rig.carrying = held() != null or carried_fixture != null
	rig.heavy = carried_fixture != null or (held() != null and held().is_heavy())
	if _action_timer > 0.0:
		_action_timer -= delta
		rig.anim = action_anim
	else:
		rig.anim = CharacterRig.Anim.WALK if rig.speed > 0.05 else CharacterRig.Anim.IDLE
	if carried_fixture:
		carried_fixture.position = Vector3(0, 0.55 + sin(Time.get_ticks_msec() * 0.006) * 0.02, 0.62)


# -----------------------------------------------------------------------------
# Network / persistence
# -----------------------------------------------------------------------------

func apply_remote_motion(pos: Vector3, yaw: float) -> void:
	_remote_target = pos
	_remote_yaw = yaw
	if not _has_remote:
		global_position = pos
		rotation.y = yaw
	_has_remote = true


func get_motion() -> Array:
	return [snappedf(global_position.x, 0.01), snappedf(global_position.z, 0.01), snappedf(rotation.y, 0.01), action_anim if _action_timer > 0.0 else -1]


func apply_motion(m: Array) -> void:
	if is_local():
		return
	apply_remote_motion(Vector3(m[0], 0, m[1]), m[2])
	if m.size() > 3 and int(m[3]) >= 0:
		play_action(int(m[3]), 0.15)


func get_state() -> Dictionary:
	var d := {"i": player_index, "peer": peer_id, "n": player_name}
	# The input device only matters on the machine that owns the player.
	if peer_id == Net.my_id():
		d["dev"] = device
	return d


func set_state(d: Dictionary) -> void:
	player_index = d.get("i", player_index)
	peer_id = d.get("peer", peer_id)
	player_name = d.get("n", player_name)
	if peer_id == Net.my_id():
		if d.has("dev"):
			device = d["dev"]
		elif device < 0:
			device = Net.local_device
	else:
		device = -1
	if is_node_ready():
		_build_look()


func get_location() -> Dictionary:
	return {"pos": [global_position.x, 0.0, global_position.z], "yaw": rotation.y}


func set_location(d: Dictionary) -> void:
	if d.has("pos"):
		var p: Array = d["pos"]
		global_position = Vector3(p[0], 0, p[2])
	rotation.y = d.get("yaw", 0.0)


func mark_dirty() -> void:
	if world and world.replicator:
		world.replicator.mark_dirty(self)


func server_tick(_delta: float) -> void:
	pass
