class_name LightingRig
extends Node3D
## Warm miniature-diorama lighting that follows the time of day:
## soft morning light during prep, a bright then golden afternoon during
## service, and a deep blue evening with glowing interiors after closing.

var env: Environment
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var sky_mat: ShaderMaterial
var builder: RestaurantBuilder

var _current := {}
var _target := {}

const KEYS := {
	# hour: [sun_color, sun_energy, sun_pitch, sun_yaw, ambient_color, ambient_energy, sky_top, sky_horizon, sky_bottom, interior, street, windows]
	7.0: [Color("ffd8a8"), 0.9, -38.0, -40.0, Color("f3e6d6"), 0.55, Color("e9d9c4"), Color("f7e3c8"), Color("8fa7a3"), 0.35, 0.0, 0.1],
	11.0: [Color("fff4e3"), 1.2, -58.0, -28.0, Color("f6efe4"), 0.6, Color("e8e2d4"), Color("f6eee0"), Color("93aaa6"), 0.3, 0.0, 0.0],
	15.0: [Color("ffefd6"), 1.15, -52.0, 10.0, Color("f6ecdd"), 0.6, Color("eadfcd"), Color("f7ead6"), Color("90a6a2"), 0.35, 0.0, 0.0],
	18.5: [Color("ffc58a"), 0.95, -30.0, 35.0, Color("f0d9c2"), 0.5, Color("e3c6ad"), Color("f4d2ad"), Color("7d8f9a"), 0.7, 0.4, 0.4],
	21.0: [Color("9fb2e0"), 0.35, -45.0, 40.0, Color("aab6d6"), 0.42, Color("3f4c6e"), Color("6a6a8a"), Color("2c3448"), 1.1, 1.2, 1.0],
	23.0: [Color("8fa3d6"), 0.3, -50.0, 40.0, Color("9aa8cc"), 0.4, Color("323c5a"), Color("54587a"), Color("232a3c"), 1.15, 1.3, 1.0],
}


func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/backdrop_sky.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f6efe4")
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.06
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 60.0
	sun.light_angular_distance = 1.5
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.name = "Fill"
	fill.shadow_enabled = false
	fill.light_energy = 0.18
	fill.light_color = Color("cfe0ff")
	fill.rotation_degrees = Vector3(-35, 150, 0)
	fill.light_specular = 0.0
	add_child(fill)
	set_hour(8.0, true)


func set_hour(hour: float, instant := false) -> void:
	_target = _sample(hour)
	if instant or _current.is_empty():
		_current = _target.duplicate()
		_apply(_current)


func _sample(hour: float) -> Dictionary:
	var hours := KEYS.keys()
	hours.sort()
	var h0: float = hours[0]
	var h1: float = hours[hours.size() - 1]
	if hour <= h0:
		return _to_dict(KEYS[h0])
	if hour >= h1:
		return _to_dict(KEYS[h1])
	for i in hours.size() - 1:
		if hour >= hours[i] and hour <= hours[i + 1]:
			var t: float = (hour - hours[i]) / (hours[i + 1] - hours[i])
			return _lerp(_to_dict(KEYS[hours[i]]), _to_dict(KEYS[hours[i + 1]]), t)
	return _to_dict(KEYS[h0])


func _to_dict(a: Array) -> Dictionary:
	return {
		"sun_color": a[0], "sun_energy": a[1], "pitch": a[2], "yaw": a[3],
		"amb_color": a[4], "amb_energy": a[5], "sky_top": a[6], "sky_hor": a[7], "sky_bot": a[8],
		"interior": a[9], "street": a[10], "windows": a[11],
	}


func _lerp(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a:
		var va = a[k]
		var vb = b[k]
		if va is Color:
			out[k] = (va as Color).lerp(vb, t)
		else:
			out[k] = lerpf(va, vb, t)
	return out


func _process(delta: float) -> void:
	if _target.is_empty():
		return
	_current = _lerp(_current, _target, clampf(delta * 1.5, 0.0, 1.0))
	_apply(_current)


func _apply(s: Dictionary) -> void:
	sun.light_color = s["sun_color"]
	sun.light_energy = s["sun_energy"]
	sun.rotation_degrees = Vector3(s["pitch"], s["yaw"], 0)
	env.ambient_light_color = s["amb_color"]
	env.ambient_light_energy = s["amb_energy"]
	sky_mat.set_shader_parameter("top_color", s["sky_top"])
	sky_mat.set_shader_parameter("horizon_color", s["sky_hor"])
	sky_mat.set_shader_parameter("bottom_color", s["sky_bot"])
	if builder and is_instance_valid(builder):
		builder.set_light_level(s["interior"], s["street"], s["windows"])


## A brief lift in exposure when the restaurant opens.
func flash_open() -> void:
	var tw := create_tween()
	env.adjustment_brightness = 1.12
	tw.tween_property(env, "adjustment_brightness", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
