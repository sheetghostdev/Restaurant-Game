class_name CharacterRig
extends Node3D
## Procedural low-poly person: moderately oversized angular head, short torso,
## stubby legs, simple mitten hands. Built from chamfered blocks (no smooth
## bean shapes) and animated procedurally, so there are no animation assets.
##
## Appearance dictionary keys (all optional):
##   skin, hair, hair_style, shirt, pants, shoes, apron (Color or null),
##   hat (StringName), hat_color, accessory (StringName), glasses (bool),
##   mustache (bool), scale (float), team (Color: dominant identity colour)

enum Anim { IDLE, WALK, SIT, EAT, CHOP, SCRUB, REPAIR, WIPE, SPRAY, COOK, WAVE, UPSET, CHEER, THINK }

const HIP_Y := 0.44
const BASE_SCALE := 1.12   ## Slightly heroic scale so people read well from above.
const TORSO_H := 0.4
const HEAD_H := 0.34

var appearance := {}
var anim := Anim.IDLE
var speed := 0.0            ## 0..1 normalised locomotion speed
var carrying := false
var heavy := false
var mood := 1.0             ## 1 happy .. 0 angry (customers)

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _mouth: MeshInstance3D
var _brows: Node3D
var _phase := 0.0
var _t := 0.0
var _squash := 0.0
var _lean := 0.0
var _mouth_state := -1

static var _mesh_cache := {}


func build(app: Dictionary) -> void:
	appearance = app
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var skin: Color = app.get("skin", Pal.SKIN_TONES[1])
	var shirt: Color = app.get("shirt", Pal.CREAM)
	var pants: Color = app.get("pants", Pal.CHARCOAL)
	var shoes: Color = app.get("shoes", Pal.RUBBER)
	var hair: Color = app.get("hair", Pal.HAIR_COLORS[0])
	_hips = _node(self, Vector3(0, HIP_Y, 0))
	# Legs (pivot at the hip)
	_leg_l = _node(_hips, Vector3(-0.1, 0, 0))
	_leg_r = _node(_hips, Vector3(0.1, 0, 0))
	for leg in [_leg_l, _leg_r]:
		_part(leg, "leg", [pants, shoes], func(b: MeshBuilder):
			b.box(Vector3(0, -0.2, 0), Vector3(0.14, 0.34, 0.15), pants, 0.03)
			b.box(Vector3(0, -0.405, 0.035), Vector3(0.15, 0.08, 0.23), shoes, 0.03)
			b.box(Vector3(0, -0.44, 0.04), Vector3(0.16, 0.012, 0.24), shoes.darkened(0.3), 0.004))
	# Torso
	_torso = _node(_hips, Vector3(0, 0.02, 0))
	var apron = app.get("apron")
	var vest = app.get("accessory") == &"vest"
	_part(_torso, "torso", [shirt, pants, apron, vest, app.get("accessory")], func(b: MeshBuilder):
		b.box(Vector3(0, 0.02, 0), Vector3(0.36, 0.12, 0.22), pants, 0.04)
		b.box(Vector3(0, TORSO_H * 0.5 + 0.02, 0), Vector3(0.42, TORSO_H - 0.04, 0.25), shirt, 0.06)
		b.box(Vector3(0, TORSO_H - 0.01, 0), Vector3(0.3, 0.06, 0.2), shirt.darkened(0.06), 0.03)
		if apron is Color:
			b.box(Vector3(0, 0.13, 0.13), Vector3(0.38, 0.34, 0.03), apron, 0.012)
			b.box(Vector3(0, 0.32, 0.128), Vector3(0.24, 0.14, 0.03), apron, 0.01)
			b.box(Vector3(0, 0.2, -0.0), Vector3(0.44, 0.04, 0.27), apron.darkened(0.15), 0.01)
			b.box(Vector3(0, 0.1, 0.15), Vector3(0.14, 0.08, 0.012), apron.darkened(0.12), 0.004)
		if vest:
			var hv := Color("f2c230")
			b.box(Vector3(0, TORSO_H * 0.5 + 0.02, 0), Vector3(0.44, TORSO_H - 0.1, 0.27), hv, 0.05)
			b.box(Vector3(0, TORSO_H * 0.42, 0.0), Vector3(0.45, 0.04, 0.28), Color("e8e8e8"))
		var acc = app.get("accessory")
		if acc == &"tie":
			b.box(Vector3(0, 0.24, 0.13), Vector3(0.06, 0.26, 0.02), Color("b5492e"), 0.008)
			b.box(Vector3(0, 0.36, 0.13), Vector3(0.08, 0.05, 0.025), Color("b5492e"), 0.008)
		elif acc == &"bowtie":
			b.box(Vector3(-0.04, 0.37, 0.13), Vector3(0.07, 0.05, 0.03), Pal.DINER_RED, 0.01)
			b.box(Vector3(0.04, 0.37, 0.13), Vector3(0.07, 0.05, 0.03), Pal.DINER_RED, 0.01)
		elif acc == &"camera":
			b.box(Vector3(0, 0.2, 0.15), Vector3(0.14, 0.09, 0.06), Pal.CHARCOAL, 0.015)
			b.box(Vector3(0, 0.2, 0.19), Vector3(0.05, 0.05, 0.03), Pal.STEEL, 0.008)
		elif acc == &"backpack":
			b.box(Vector3(0, 0.22, -0.18), Vector3(0.3, 0.3, 0.12), Color("6a9a9a"), 0.04)
		elif acc == &"notebook":
			b.box(Vector3(0.16, 0.18, 0.14), Vector3(0.1, 0.14, 0.03), Pal.CREAM, 0.008))
	# Arms (pivot at the shoulder)
	_arm_l = _node(_torso, Vector3(-0.25, TORSO_H - 0.07, 0))
	_arm_r = _node(_torso, Vector3(0.25, TORSO_H - 0.07, 0))
	for side in [-1.0, 1.0]:
		var arm := _arm_l if side < 0 else _arm_r
		_part(arm, "arm%d" % int(side), [shirt, skin], func(b: MeshBuilder):
			b.box(Vector3(0, -0.12, 0), Vector3(0.11, 0.24, 0.12), shirt, 0.03)
			b.box(Vector3(0, -0.29, 0), Vector3(0.1, 0.12, 0.11), skin, 0.03)
			b.box(Vector3(0, -0.34, 0.015), Vector3(0.12, 0.08, 0.13), skin, 0.035))
	# Head
	_head = _node(_torso, Vector3(0, TORSO_H + 0.01, 0))
	var style: StringName = app.get("hair_style", &"short")
	_part(_head, "head", [skin, hair, style, app.get("glasses", false), app.get("mustache", false)], func(b: MeshBuilder):
		b.box(Vector3(0, 0.03, 0), Vector3(0.12, 0.08, 0.12), skin, 0.02)
		b.box(Vector3(0, HEAD_H * 0.5 + 0.05, 0), Vector3(0.36, HEAD_H, 0.34), skin, 0.07)
		# Ears
		for s in [-1.0, 1.0]:
			b.box(Vector3(s * 0.185, HEAD_H * 0.5 + 0.04, -0.01), Vector3(0.04, 0.08, 0.07), skin.darkened(0.06), 0.015)
		# Eyes + nose
		for s in [-1.0, 1.0]:
			b.box(Vector3(s * 0.075, HEAD_H * 0.55 + 0.05, 0.172), Vector3(0.045, 0.07, 0.012), Color("2a221d"), 0.008)
			b.box(Vector3(s * 0.067, HEAD_H * 0.58 + 0.05, 0.178), Vector3(0.015, 0.02, 0.006), Color(1, 1, 1))
		b.box(Vector3(0, HEAD_H * 0.42 + 0.05, 0.18), Vector3(0.06, 0.07, 0.05), skin.darkened(0.08), 0.015)
		if app.get("mustache", false):
			b.box(Vector3(0, HEAD_H * 0.31 + 0.05, 0.18), Vector3(0.16, 0.045, 0.04), hair, 0.015)
		if app.get("glasses", false):
			for s in [-1.0, 1.0]:
				b.box(Vector3(s * 0.075, HEAD_H * 0.55 + 0.05, 0.185), Vector3(0.1, 0.09, 0.012), Pal.CHARCOAL, 0.006)
				b.box(Vector3(s * 0.075, HEAD_H * 0.55 + 0.05, 0.19), Vector3(0.07, 0.06, 0.006), Color("bfe3ea"))
			b.box(Vector3(0, HEAD_H * 0.58 + 0.05, 0.188), Vector3(0.06, 0.015, 0.01), Pal.CHARCOAL)
		_hair(b, style, hair))
	# Brows (separate so they can express mood)
	_brows = _node(_head, Vector3(0, HEAD_H * 0.74 + 0.05, 0.176))
	for s in [-1.0, 1.0]:
		var brow := _node(_brows, Vector3(s * 0.075, 0, 0))
		_part(brow, "brow", [hair], func(b: MeshBuilder):
			b.box(Vector3.ZERO, Vector3(0.07, 0.018, 0.012), hair.darkened(0.2), 0.004))
	_mouth = MeshInstance3D.new()
	_mouth.position = Vector3(0, HEAD_H * 0.24 + 0.05, 0.176)
	_head.add_child(_mouth)
	_mouth_state = -1
	_set_mouth(0)
	# Hat
	var hat: StringName = app.get("hat", &"none")
	if hat != &"none":
		var hat_col: Color = app.get("hat_color", Pal.CREAM)
		var hn := _node(_head, Vector3(0, HEAD_H + 0.05, 0))
		_part(hn, "hat", [hat, hat_col], func(b: MeshBuilder): _hat(b, hat, hat_col))
	scale = Vector3.ONE * float(app.get("scale", 1.0)) * BASE_SCALE


func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, part: String, key_parts: Array, fn: Callable) -> MeshInstance3D:
	var key := part
	for k in key_parts:
		key += "|" + (k.to_html() if k is Color else str(k))
	var mesh: Mesh = _mesh_cache.get(key)
	if mesh == null:
		var b := MeshBuilder.new()
		b.ao_strength = 0.12
		b.contact_shade = 0.0
		fn.call(b)
		mesh = b.commit(Models.mat_main())
		_mesh_cache[key] = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


func _hair(b: MeshBuilder, style: StringName, col: Color) -> void:
	var top := HEAD_H + 0.05
	match style:
		&"short":
			b.box(Vector3(0, top - 0.02, -0.02), Vector3(0.38, 0.1, 0.34), col, 0.04)
			b.box(Vector3(0, top - 0.12, -0.15), Vector3(0.38, 0.18, 0.08), col, 0.03)
			b.box(Vector3(0.08, top + 0.0, 0.12), Vector3(0.22, 0.07, 0.1), col, 0.02)
		&"long":
			b.box(Vector3(0, top - 0.02, -0.02), Vector3(0.39, 0.1, 0.35), col, 0.04)
			b.box(Vector3(0, top - 0.22, -0.15), Vector3(0.4, 0.4, 0.1), col, 0.04)
			for s in [-1.0, 1.0]:
				b.box(Vector3(s * 0.19, top - 0.17, 0.02), Vector3(0.05, 0.28, 0.24), col, 0.02)
		&"bun":
			b.box(Vector3(0, top - 0.02, -0.02), Vector3(0.38, 0.09, 0.34), col, 0.04)
			b.box(Vector3(0, top - 0.1, -0.15), Vector3(0.38, 0.14, 0.08), col, 0.03)
			b.box(Vector3(0, top + 0.08, -0.1), Vector3(0.16, 0.14, 0.15), col, 0.05)
		&"spiky":
			for k in 5:
				b.push_at(Vector3(-0.14 + k * 0.07, top, 0.0), 0.0, Vector3.ONE, 0.0, (k - 2) * 0.18)
				b.cyl(Vector3.ZERO, 0.06, 0.13, col, 4, 0.0, Color(0, 0, 0, 0), 0.01)
				b.pop()
			b.box(Vector3(0, top - 0.04, -0.03), Vector3(0.38, 0.08, 0.33), col, 0.03)
		&"pony":
			b.box(Vector3(0, top - 0.02, -0.02), Vector3(0.38, 0.1, 0.34), col, 0.04)
			b.box(Vector3(0, top - 0.06, -0.21), Vector3(0.1, 0.12, 0.12), col, 0.03)
			b.box(Vector3(0, top - 0.22, -0.24), Vector3(0.09, 0.24, 0.08), col, 0.03)
		&"curly":
			for k in 7:
				var a := TAU * k / 7.0
				b.sphere(Vector3(cos(a) * 0.13, top - 0.01, sin(a) * 0.12 - 0.03), Vector3(0.08, 0.07, 0.08), col, 0)
			b.sphere(Vector3(0, top + 0.03, -0.03), Vector3(0.12, 0.07, 0.1), col, 0)
		_:
			pass


func _hat(b: MeshBuilder, hat: StringName, col: Color) -> void:
	match hat:
		&"chef":
			b.cyl(Vector3(0, -0.02, 0), 0.19, 0.09, col.lerp(Color.WHITE, 0.0), 8, 0.02)
			b.cyl(Vector3(0, 0.06, 0), 0.17, 0.12, Color("f8f6f0"), 8, 0.02, Color(0, 0, 0, 0), 0.21)
			b.sphere(Vector3(0, 0.22, 0), Vector3(0.23, 0.1, 0.21), Color("f8f6f0"), 1)
		&"cap":
			b.box(Vector3(0, 0.02, -0.01), Vector3(0.38, 0.1, 0.36), col, 0.05)
			b.box(Vector3(0, -0.02, 0.22), Vector3(0.3, 0.025, 0.18), col.darkened(0.1), 0.01)
			b.box(Vector3(0, 0.075, -0.01), Vector3(0.05, 0.02, 0.05), col.lightened(0.2), 0.008)
		&"bandana":
			b.box(Vector3(0, -0.04, 0), Vector3(0.385, 0.08, 0.355), col, 0.02)
			b.box(Vector3(0.05, -0.08, -0.2), Vector3(0.1, 0.1, 0.05), col, 0.02)
		&"beanie":
			b.box(Vector3(0, 0.0, -0.01), Vector3(0.39, 0.13, 0.36), col, 0.06)
			b.box(Vector3(0, -0.06, -0.01), Vector3(0.4, 0.06, 0.37), col.darkened(0.15), 0.02)
			b.sphere(Vector3(0, 0.1, -0.01), Vector3(0.06, 0.05, 0.06), col.lightened(0.2), 0)
		&"hard_hat":
			b.cyl(Vector3(0, -0.04, 0), 0.25, 0.03, col, 8, 0.01)
			b.cyl(Vector3(0, -0.02, 0), 0.19, 0.13, col, 8, 0.04, Color(0, 0, 0, 0), 0.13)
		&"beret":
			b.box(Vector3(0.03, 0.0, 0.0), Vector3(0.36, 0.07, 0.34), col, 0.03)
			b.box(Vector3(0.0, 0.05, 0.0), Vector3(0.02, 0.04, 0.02), col)
		&"sun_hat":
			b.cyl(Vector3(0, -0.03, 0), 0.32, 0.025, col, 10, 0.008)
			b.cyl(Vector3(0, -0.01, 0), 0.19, 0.12, col, 10, 0.03)
			b.cyl(Vector3(0, 0.01, 0), 0.195, 0.03, Pal.DINER_RED, 10)
		&"bow":
			b.box(Vector3(0.1, 0.02, 0.0), Vector3(0.09, 0.07, 0.06), col, 0.02)
			b.box(Vector3(0.19, 0.02, 0.0), Vector3(0.09, 0.07, 0.06), col, 0.02)
		&"antennae":
			for x in [-0.09, 0.09]:
				b.box(Vector3(x, 0.06, 0.0), Vector3(0.025, 0.18, 0.025), col.darkened(0.2))
				b.sphere(Vector3(x, 0.17, 0.0), Vector3(0.045, 0.045, 0.045), col.lightened(0.25), 0)
		_:
			pass


func _set_mouth(state: int) -> void:
	if state == _mouth_state:
		return
	_mouth_state = state
	var key := "mouth%d" % state
	var mesh: Mesh = _mesh_cache.get(key)
	if mesh == null:
		var b := MeshBuilder.new()
		b.ao_strength = 0.0
		var c := Color("5a2a22")
		match state:
			0: # smile
				b.box(Vector3(0, 0, 0), Vector3(0.1, 0.022, 0.012), c, 0.006)
				b.box(Vector3(-0.055, 0.014, 0), Vector3(0.025, 0.022, 0.012), c, 0.006)
				b.box(Vector3(0.055, 0.014, 0), Vector3(0.025, 0.022, 0.012), c, 0.006)
			1: # neutral
				b.box(Vector3.ZERO, Vector3(0.09, 0.02, 0.012), c, 0.006)
			2: # frown
				b.box(Vector3(0, 0.012, 0), Vector3(0.1, 0.022, 0.012), c, 0.006)
				b.box(Vector3(-0.055, -0.004, 0), Vector3(0.025, 0.022, 0.012), c, 0.006)
				b.box(Vector3(0.055, -0.004, 0), Vector3(0.025, 0.022, 0.012), c, 0.006)
			3: # open (eating / shouting)
				b.box(Vector3.ZERO, Vector3(0.07, 0.06, 0.012), c, 0.012)
		mesh = b.commit(Models.mat_main())
		_mesh_cache[key] = mesh
	_mouth.mesh = mesh


func squash(amount := 1.0) -> void:
	_squash = maxf(_squash, amount)


func _process(delta: float) -> void:
	if _hips == null:
		return
	_t += delta
	var spd := clampf(speed, 0.0, 1.4)
	_phase += delta * (4.0 + 8.0 * spd) * (0.85 if heavy else 1.0)
	var swing := sin(_phase) * 0.75 * clampf(spd * 1.3, 0.0, 1.0)
	var bob := absf(sin(_phase)) * 0.045 * clampf(spd * 1.5, 0.0, 1.0)
	var breathe := sin(_t * 2.2) * 0.008
	# Legs
	var leg_l := swing
	var leg_r := -swing
	var hip_y := HIP_Y + bob
	if anim == Anim.SIT or anim == Anim.EAT or (anim == Anim.THINK and speed < 0.05 and appearance.get("seated", false)):
		leg_l = -1.45
		leg_r = -1.45
		hip_y = HIP_Y + 0.02
	_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, leg_l, clampf(delta * 18.0, 0, 1))
	_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, leg_r, clampf(delta * 18.0, 0, 1))
	_hips.position.y = lerpf(_hips.position.y, hip_y, clampf(delta * 20.0, 0, 1))
	# Lean with speed (and back when hauling something heavy)
	var target_lean := spd * 0.14 - (0.12 if heavy and carrying else 0.0)
	_lean = lerpf(_lean, target_lean, clampf(delta * 8.0, 0, 1))
	_torso.rotation.x = _lean
	_torso.scale = Vector3(1.0, 1.0 + breathe, 1.0)
	# Arms
	var al := Vector3(-swing * 0.8, 0, 0.08)
	var ar := Vector3(swing * 0.8, 0, -0.08)
	var tt := _t
	match anim:
		Anim.CHOP:
			ar = Vector3(-1.1 - absf(sin(tt * 14.0)) * 0.9, 0, -0.1)
			al = Vector3(-1.2, 0, 0.35)
		Anim.SCRUB:
			al = Vector3(-1.15 + sin(tt * 10.0) * 0.25, cos(tt * 10.0) * 0.2, 0.2)
			ar = Vector3(-1.15 - sin(tt * 10.0) * 0.25, cos(tt * 10.0) * 0.2, -0.2)
		Anim.REPAIR:
			ar = Vector3(-1.3, sin(tt * 9.0) * 0.6, -0.2)
			al = Vector3(-0.9, 0, 0.25)
		Anim.WIPE:
			al = Vector3(-1.2, sin(tt * 7.0) * 0.5, 0.15)
			ar = Vector3(-1.2, sin(tt * 7.0) * 0.5, -0.15)
		Anim.SPRAY:
			al = Vector3(-1.45, 0, 0.12)
			ar = Vector3(-1.45, 0, -0.12)
		Anim.COOK:
			ar = Vector3(-1.2 + sin(tt * 8.0) * 0.3, 0, -0.15)
		Anim.WAVE:
			ar = Vector3(-2.9 + sin(tt * 8.0) * 0.15, 0, -0.3 + sin(tt * 8.0) * 0.2)
		Anim.EAT:
			ar = Vector3(-1.6 - absf(sin(tt * 3.0)) * 0.6, 0, -0.35)
			al = Vector3(-0.9, 0, 0.2)
		Anim.SIT:
			al = Vector3(-0.8, 0, 0.15)
			ar = Vector3(-0.8, 0, -0.15)
		Anim.UPSET:
			al = Vector3(-1.4, 0.0, 0.9)
			ar = Vector3(-1.4, 0.0, -0.9)
		Anim.CHEER:
			al = Vector3(-2.8, 0, 0.4 + sin(tt * 10.0) * 0.1)
			ar = Vector3(-2.8, 0, -0.4 - sin(tt * 10.0) * 0.1)
		Anim.THINK:
			ar = Vector3(-2.0, 0, -0.5)
	if carrying and anim in [Anim.IDLE, Anim.WALK]:
		var lift := -1.25 if not heavy else -1.0
		al = Vector3(lift + swing * 0.08, 0, 0.12)
		ar = Vector3(lift - swing * 0.08, 0, -0.12)
	var k := clampf(delta * 16.0, 0, 1)
	_arm_l.rotation = Vector3(lerp_angle(_arm_l.rotation.x, al.x, k), lerp_angle(_arm_l.rotation.y, al.y, k), lerp_angle(_arm_l.rotation.z, al.z, k))
	_arm_r.rotation = Vector3(lerp_angle(_arm_r.rotation.x, ar.x, k), lerp_angle(_arm_r.rotation.y, ar.y, k), lerp_angle(_arm_r.rotation.z, ar.z, k))
	# Head: small bob and nod while working
	var nod := 0.0
	if anim in [Anim.CHOP, Anim.SCRUB, Anim.REPAIR, Anim.WIPE]:
		nod = 0.25 + sin(tt * 7.0) * 0.05
	elif anim == Anim.EAT:
		nod = 0.15 + absf(sin(tt * 3.0)) * 0.12
	_head.rotation.x = lerpf(_head.rotation.x, nod + sin(_t * 1.7) * 0.02, clampf(delta * 8.0, 0, 1))
	_head.rotation.z = sin(_phase * 0.5) * 0.04 * spd
	# Expression
	if anim == Anim.EAT and fmod(_t, 1.2) < 0.4:
		_set_mouth(3)
	elif anim == Anim.CHEER:
		_set_mouth(3)
	elif mood > 0.66:
		_set_mouth(0)
	elif mood > 0.33:
		_set_mouth(1)
	else:
		_set_mouth(2)
	if _brows:
		var angry := clampf(1.0 - mood * 2.0, 0.0, 1.0)
		var bl: Node3D = _brows.get_child(0)
		var br: Node3D = _brows.get_child(1)
		bl.rotation.z = -angry * 0.45
		br.rotation.z = angry * 0.45
		_brows.position.y = HEAD_H * 0.74 + 0.05 - angry * 0.012
	# Squash & stretch
	if _squash > 0.0:
		_squash = maxf(_squash - delta * 5.0, 0.0)
		var s := sin(_squash * PI) * 0.1
		scale = Vector3.ONE * float(appearance.get("scale", 1.0)) * BASE_SCALE * Vector3(1.0 + s, 1.0 - s, 1.0 + s)
	elif not is_equal_approx(scale.y, float(appearance.get("scale", 1.0)) * BASE_SCALE):
		scale = Vector3.ONE * float(appearance.get("scale", 1.0)) * BASE_SCALE


static func random_appearance(rng: RandomNumberGenerator) -> Dictionary:
	var styles := [&"short", &"long", &"bun", &"spiky", &"pony", &"curly", &"none"]
	return {
		"skin": Pal.pick(Pal.SKIN_TONES, rng),
		"hair": Pal.pick(Pal.HAIR_COLORS, rng),
		"hair_style": Pal.pick(styles, rng),
		"shirt": Pal.pick(Pal.CLOTH_COLORS, rng),
		"pants": Pal.pick(Pal.CLOTH_COLORS, rng).darkened(0.35),
		"shoes": Pal.pick([Pal.RUBBER, Pal.WALNUT, Color("e8e2d6"), Pal.CHARCOAL], rng),
		"glasses": rng.randf() < 0.18,
		"mustache": rng.randf() < 0.1,
	}
