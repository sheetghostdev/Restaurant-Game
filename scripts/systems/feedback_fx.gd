class_name FeedbackFX
extends Node
## Juice: steam, smoke, sparkles, chopping bits, coins, floating text, pings.
##
## Calls made on the authority are mirrored to clients (via Net) unless
## `local` is true. Effects driven from _process (which already runs on every
## peer) pass local = true.

var world: GameWorld
var _puff_mat: StandardMaterial3D
var _quad: QuadMesh
var _bit_mesh: BoxMesh
var _coin_mesh: CylinderMesh


func _ready() -> void:
	world = get_parent().get_parent() as GameWorld
	_puff_mat = StandardMaterial3D.new()
	_puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puff_mat.vertex_color_use_as_albedo = true
	_puff_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_puff_mat.albedo_texture = UIArt.soft_dot(64)
	_puff_mat.disable_receive_shadows = true
	_quad = QuadMesh.new()
	_quad.size = Vector2(0.3, 0.3)
	_quad.material = _puff_mat
	_bit_mesh = BoxMesh.new()
	_bit_mesh.size = Vector3(0.04, 0.025, 0.04)
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.roughness = 0.6
	_bit_mesh.material = bm
	_coin_mesh = CylinderMesh.new()
	_coin_mesh.top_radius = 0.06
	_coin_mesh.bottom_radius = 0.06
	_coin_mesh.height = 0.018
	_coin_mesh.radial_segments = 10
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color("f2c230")
	cm.metallic = 0.6
	cm.roughness = 0.35
	cm.emission_enabled = true
	cm.emission = Color("f2c230")
	cm.emission_energy_multiplier = 0.25
	_coin_mesh.material = cm


func _relay(method: StringName, args: Array, local: bool) -> void:
	if not local and Net.is_authority() and Net.is_online():
		Net.relay_fx(method, args)


func _burst(pos: Vector3, mesh: Mesh, color: Color, amount: int, lifetime: float, vel: float, spread: float, gravity: Vector3, scale_min := 0.6, scale_max := 1.2, dir := Vector3.UP, fade := true) -> void:
	if world == null:
		return
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vel * 0.6
	p.initial_velocity_max = vel
	p.gravity = gravity
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color = color
	if fade:
		var g := Gradient.new()
		g.set_color(0, Color(color.r, color.g, color.b, color.a))
		g.set_color(1, Color(color.r, color.g, color.b, 0.0))
		p.color_ramp = g
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.8))
	p.scale_amount_curve = curve
	p.position = pos
	world.effects_root.add_child(p)
	p.emitting = true
	var t := get_tree().create_timer(lifetime + 0.3)
	t.timeout.connect(p.queue_free)


func steam(pos: Vector3, scale := 1.0, color := Color(1, 1, 1, 0.55), local := false) -> void:
	_burst(pos, _quad, color, 3, 1.1, 0.5 * scale, 20.0, Vector3(0, 0.6, 0), 0.6 * scale, 1.1 * scale)
	_relay(&"steam", [pos, scale, color], local)


func smoke(pos: Vector3, scale := 1.0, local := false) -> void:
	_burst(pos, _quad, Color(0.25, 0.23, 0.22, 0.6), 4, 1.6, 0.6 * scale, 25.0, Vector3(0, 0.5, 0), 0.8 * scale, 1.6 * scale)
	_relay(&"smoke", [pos, scale], local)


func sparkle(pos: Vector3, color := Color(1, 0.9, 0.5), local := false) -> void:
	_burst(pos, _quad, Color(color.r, color.g, color.b, 0.95), 10, 0.6, 1.6, 180.0, Vector3(0, -1.5, 0), 0.15, 0.4)
	_relay(&"sparkle", [pos, color], local)


func chop_bits(pos: Vector3, color: Color, local := false) -> void:
	_burst(pos, _bit_mesh, color, 5, 0.5, 1.4, 70.0, Vector3(0, -9, 0), 0.6, 1.2, Vector3.UP, false)
	_relay(&"chop_bits", [pos, color], local)


func bubbles(pos: Vector3, local := false) -> void:
	_burst(pos, _quad, Color(0.85, 0.95, 1.0, 0.8), 5, 0.8, 0.6, 50.0, Vector3(0, 0.2, 0), 0.2, 0.45)
	_relay(&"bubbles", [pos], local)


func sparks(pos: Vector3, local := false) -> void:
	_burst(pos, _bit_mesh, Color("ffd36b"), 14, 0.7, 3.0, 80.0, Vector3(0, -8, 0), 0.3, 0.7, Vector3.UP, false)
	smoke(pos, 1.0, true)
	_relay(&"sparks", [pos], local)


func dust(pos: Vector3, local := false) -> void:
	_burst(pos + Vector3(0, 0.05, 0), _quad, Color(0.85, 0.8, 0.72, 0.45), 2, 0.5, 0.4, 60.0, Vector3.ZERO, 0.4, 0.7)
	_relay(&"dust", [pos], local)


func foam(pos: Vector3, dir: Vector3, local := false) -> void:
	_burst(pos, _quad, Color(0.95, 0.97, 1.0, 0.85), 6, 0.6, 4.5, 14.0, Vector3(0, -2, 0), 0.5, 1.1, dir)
	_relay(&"foam", [pos, dir], local)


func coins(pos: Vector3, amount: float, local := false) -> void:
	var n := clampi(int(amount / 4.0), 3, 14)
	_burst(pos, _coin_mesh, Color(1, 1, 1), n, 0.9, 3.2, 35.0, Vector3(0, -9, 0), 0.8, 1.2, Vector3.UP, false)
	popup_text(pos + Vector3(0, 0.4, 0), "+" + GameConst.money(amount), Pal.UI_MONEY, true)
	Events.coins_popped.emit(amount, pos)
	_relay(&"coins", [pos, amount], local)


func popup_text(pos: Vector3, text: String, color := Color.WHITE, local := false) -> void:
	if world == null:
		return
	var l := Label3D.new()
	l.text = text
	l.font = load("res://art/fonts/AlfaSlabOne-Regular.ttf")
	l.font_size = 56
	l.pixel_size = 0.0042
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0.12, 0.1, 0.09, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	l.position = pos
	world.effects_root.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", pos + Vector3(0, 0.7, 0), 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	l.scale = Vector3.ONE * 0.4
	tw.tween_property(l, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.9)
	tw.chain().tween_callback(l.queue_free)
	_relay(&"popup_text", [pos, text, color], local)


func ping(pos: Vector3, color: Color, local := false) -> void:
	if world == null:
		return
	var root := Node3D.new()
	root.position = Vector3(pos.x, maxf(pos.y, 0.0) + 1.3, pos.z)
	var m := MeshInstance3D.new()
	m.mesh = Models.mesh(&"ping_marker")
	m.material_override = Models.mat_unshaded(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	var ring := MeshInstance3D.new()
	ring.mesh = Models.mesh(&"ring")
	ring.material_override = Models.mat_unshaded(Color(color.r, color.g, color.b, 0.8), true)
	ring.position = Vector3(0, -1.28, 0)
	root.add_child(ring)
	world.effects_root.add_child(root)
	var tw := root.create_tween()
	tw.tween_property(m, "position:y", 0.25, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(m, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.set_loops(4)
	var tw2 := root.create_tween()
	tw2.tween_property(ring, "scale", Vector3.ONE * 2.2, 1.2)
	tw2.tween_interval(1.2)
	tw2.tween_callback(root.queue_free)
	Audio.play_at(&"ping", pos, -4.0, 1.0, true)
	Events.ping.emit(pos, color)
	_relay(&"ping", [pos, color], local)
