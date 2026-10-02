class_name Models
## Central model library. Meshes are generated procedurally on first request and
## cached by key, so every grill in the restaurant shares one ArrayMesh and one
## material (cheap to render, trivially instanced).
##
## Builders live in category scripts (ModelsFood, ModelsKitchen, ...). To replace
## a procedural placeholder with an authored asset, drop a scene or mesh at
## res://art/models/<key>.tscn / .glb / .res and it will be used instead.

static var _meshes := {}
static var _materials := {}


static func mat_main() -> ShaderMaterial:
	if not _materials.has(&"main"):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/diorama.gdshader")
		_materials[&"main"] = m
	return _materials[&"main"]


static func mat_food() -> ShaderMaterial:
	if not _materials.has(&"food"):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/diorama.gdshader")
		m.set_shader_parameter("roughness_value", 0.55)
		m.set_shader_parameter("specular_value", 0.45)
		m.set_shader_parameter("rim_strength", 0.1)
		m.set_shader_parameter("saturation", 1.12)
		_materials[&"food"] = m
	return _materials[&"food"]


static func mat_glass() -> StandardMaterial3D:
	if not _materials.has(&"glass"):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.75, 0.9, 0.95, 0.28)
		m.roughness = 0.05
		m.metallic_specular = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[&"glass"] = m
	return _materials[&"glass"]


static func mat_emissive(color: Color, energy := 1.5) -> StandardMaterial3D:
	var key := StringName("emit_%s_%.2f" % [color.to_html(), energy])
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		m.roughness = 0.6
		_materials[key] = m
	return _materials[key]


static func mat_unshaded(color: Color, transparent := false) -> StandardMaterial3D:
	var key := StringName("unshaded_%s_%s" % [color.to_html(), transparent])
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		if transparent:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.disable_receive_shadows = true
		_materials[key] = m
	return _materials[key]


## Target highlight: an outline shell in the player's colour, followed by a
## soft additive fill/rim pass.
static func mat_highlight(color: Color) -> ShaderMaterial:
	var key := StringName("hl_%s" % color.to_html())
	if not _materials.has(key):
		var outline := ShaderMaterial.new()
		outline.shader = load("res://shaders/highlight_outline.gdshader")
		outline.set_shader_parameter("color", color)
		var fill := ShaderMaterial.new()
		fill.shader = load("res://shaders/highlight_overlay.gdshader")
		fill.set_shader_parameter("color", color)
		outline.next_pass = fill
		_materials[key] = outline
	return _materials[key]


static func mat_ghost(ok: bool) -> ShaderMaterial:
	var key := &"ghost_ok" if ok else &"ghost_bad"
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/ghost.gdshader")
		m.set_shader_parameter("color", Color(0.35, 0.95, 0.55, 0.5) if ok else Color(1.0, 0.35, 0.3, 0.5))
		_materials[key] = m
	return _materials[key]


## Returns the cached mesh for `key`, building it if needed.
static func mesh(key: StringName) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var override_path := "res://art/models/%s.res" % key
	if ResourceLoader.exists(override_path):
		_meshes[key] = load(override_path)
		return _meshes[key]
	var b := MeshBuilder.new()
	var food := false
	if ModelsFood.build(key, b):
		food = true
	elif ModelsKitchen.build(key, b):
		pass
	elif ModelsFurniture.build(key, b):
		pass
	elif ModelsProps.build(key, b):
		pass
	else:
		push_warning("Models: unknown model key '%s'" % key)
		b.block(Vector3.ZERO, Vector3(0.3, 0.3, 0.3), Color.MAGENTA, 0.03)
	var m := b.commit(mat_food() if food else mat_main())
	_meshes[key] = m
	return m


## Creates a MeshInstance3D for `key`. If an authored scene exists at
## res://art/models/<key>.tscn it is instanced instead.
static func instance(key: StringName) -> Node3D:
	var scene_path := "res://art/models/%s.tscn" % key
	if ResourceLoader.exists(scene_path):
		return (load(scene_path) as PackedScene).instantiate()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(key)
	mi.name = String(key)
	return mi


static func has_cached(key: StringName) -> bool:
	return _meshes.has(key)


## Registers a mesh generated elsewhere (e.g. parametric variants).
static func store(key: StringName, m: Mesh) -> void:
	_meshes[key] = m


static func clear_cache() -> void:
	_meshes.clear()
