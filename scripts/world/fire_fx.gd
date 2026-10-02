class_name FireFX
extends Node3D
## Chunky stylised flames + smoke + flickering light for grease fires.

var intensity := 0.0
var _tongues: Array[MeshInstance3D] = []
var _flames: CPUParticles3D
var _smoke: CPUParticles3D
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	# Chunky low-poly flame tongues: the main readable shape.
	var cols := [Color("ffd23f"), Color("ff8a2a"), Color("ff5a1f"), Color("ffb02e"), Color("ff7425")]
	for i in 5:
		var b := MeshBuilder.new()
		b.ao_strength = 0.0
		b.cyl(Vector3.ZERO, 0.16 - i * 0.012, 0.5 + (i % 3) * 0.12, Color(1, 1, 1), 5, 0.0, Color(0, 0, 0, 0), 0.0)
		var mi := MeshInstance3D.new()
		mi.mesh = b.commit()
		mi.material_override = Models.mat_emissive(cols[i], 2.2)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / 5.0
		mi.position = Vector3(cos(a) * 0.17, 0.0, sin(a) * 0.15) if i > 0 else Vector3.ZERO
		add_child(mi)
		_tongues.push_back(mi)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.albedo_texture = UIArt.soft_dot(64)
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.75)
	q.material = fm
	_flames = CPUParticles3D.new()
	_flames.mesh = q
	_flames.amount = 36
	_flames.lifetime = 0.7
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flames.emission_box_extents = Vector3(0.32, 0.05, 0.3)
	_flames.direction = Vector3.UP
	_flames.spread = 12.0
	_flames.initial_velocity_min = 0.8
	_flames.initial_velocity_max = 1.6
	_flames.gravity = Vector3(0, 1.0, 0)
	_flames.scale_amount_min = 0.7
	_flames.scale_amount_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.5, 1.0))
	g.add_point(0.35, Color(1.0, 0.55, 0.15, 0.95))
	g.set_color(g.get_point_count() - 1, Color(0.9, 0.2, 0.1, 0.0))
	_flames.color_ramp = g
	add_child(_flames)
	var sm := fm.duplicate() as StandardMaterial3D
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.6, 0.6)
	q2.material = sm
	_smoke = CPUParticles3D.new()
	_smoke.mesh = q2
	_smoke.amount = 12
	_smoke.lifetime = 2.0
	_smoke.position = Vector3(0, 0.5, 0)
	_smoke.direction = Vector3.UP
	_smoke.spread = 20.0
	_smoke.initial_velocity_min = 0.6
	_smoke.initial_velocity_max = 1.0
	_smoke.gravity = Vector3(0.2, 0.4, 0)
	_smoke.scale_amount_min = 0.8
	_smoke.scale_amount_max = 1.8
	var g2 := Gradient.new()
	g2.set_color(0, Color(0.2, 0.18, 0.17, 0.55))
	g2.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	_smoke.color_ramp = g2
	add_child(_smoke)
	_light = OmniLight3D.new()
	_light.light_color = Color("ff9a4a")
	_light.omni_range = 4.0
	_light.position = Vector3(0, 0.6, 0)
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	var on := intensity > 0.01
	_flames.emitting = on
	_smoke.emitting = on
	var s := 0.6 + intensity * 0.6
	_flames.scale_amount_min = 0.6 * s
	_flames.scale_amount_max = 1.3 * s
	_light.light_energy = (2.6 + sin(_t * 23.0) * 0.5 + sin(_t * 9.0) * 0.4) * intensity if on else move_toward(_light.light_energy, 0.0, delta * 4.0)
	for i in _tongues.size():
		var mi := _tongues[i]
		mi.visible = on
		if on:
			var f := 0.75 + 0.25 * sin(_t * (11.0 + i * 3.1) + i) + 0.1 * sin(_t * 27.0 + i * 2.0)
			var flame := (0.55 + intensity * 0.6)
			mi.scale = Vector3(flame * (1.1 - f * 0.2), flame * f * 1.2, flame * (1.1 - f * 0.2))
			mi.rotation.y = _t * (1.5 + i * 0.3)
			mi.rotation.z = sin(_t * 6.0 + i) * 0.12


func is_finished() -> bool:
	return intensity <= 0.01 and _light.light_energy <= 0.01
