class_name IconRenderer
extends Node
## Renders 3D models (recipes, ingredients, fixtures) into small textures for
## the HUD and catalog, so every icon is literally the in-game model. Rendered
## lazily, one per frame, through a private SubViewport.

static var instance: IconRenderer

const SIZE := 128

var _cache := {}
var _queue: Array = []
var _viewport: SubViewport
var _stage: Node3D
var _cam: Camera3D
var _busy := false


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff3e3")
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	_viewport.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_cam)
	_stage = Node3D.new()
	_viewport.add_child(_stage)


## Returns the icon texture for a key ("recipe:burger", "item:tomato",
## "fixture:grill"), or a placeholder until it has been rendered.
func icon(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8))
	_cache[key] = tex
	_queue.push_back(key)
	if not _busy:
		_render_next.call_deferred()
	return tex


static func get_icon(key: String) -> Texture2D:
	if instance == null or DisplayServer.get_name() == "headless":
		return null
	return instance.icon(key)


func _build(key: String) -> Dictionary:
	var parts := key.split(":")
	var kind := parts[0]
	var id := StringName(parts[1]) if parts.size() > 1 else &""
	var n: Node3D
	var size := 0.55
	match kind:
		"recipe":
			var r := Content.recipe(id)
			if r:
				n = DishPlating.make_recipe_model(r)
				size = 0.5 if r.container == "plate" else 0.32
		"item":
			var d := Content.item(id)
			if d:
				n = Models.instance(d.model)
				size = 0.36
				if d.cook_profile:
					var c := d.cook_profile.color_at(0.0)
					for mi in Item._mesh_instances(n):
						mi.set_instance_shader_parameter(&"mult", Vector3(c.r, c.g, c.b))
		"fixture":
			var f := Content.fixture(id)
			if f:
				n = Models.instance(f.model if f.model != &"" else f.id)
				size = 1.5 if f.id != &"fridge" else 2.2
		"model":
			n = Models.instance(id)
			size = 1.0
		"staff":
			var sd: StaffDef = Content.staff.get(id)
			var rig := CharacterRig.new()
			var app := CharacterRig.random_appearance(RandomNumberGenerator.new())
			app["apron"] = sd.uniform if sd else Color.GRAY
			app["hat"] = &"cap"
			app["hat_color"] = sd.uniform if sd else Color.GRAY
			app["shirt"] = Color("e8e4dc")
			rig.build(app)
			n = rig
			size = 1.5
	return {"node": n, "size": size}


func _render_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var key: String = _queue.pop_front()
	var spec := _build(key)
	var n: Node3D = spec["node"]
	if n == null:
		_render_next.call_deferred()
		return
	for c in _stage.get_children():
		c.queue_free()
	_stage.add_child(n)
	var s: float = spec["size"]
	_cam.size = s * 1.25
	var target := Vector3(0, s * 0.32, 0)
	_cam.position = target + Vector3(0, 0.75, 1.0).normalized() * 10.0
	_cam.look_at(target)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	if img:
		(_cache[key] as ImageTexture).set_image(img)
	_render_next.call_deferred()
