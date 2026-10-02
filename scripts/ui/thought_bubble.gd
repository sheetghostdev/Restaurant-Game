class_name ThoughtBubble
extends Node3D
## Camera-facing speech bubble above a customer. Shows the actual 3D dish they
## want (so a burger order *looks* like a burger), or a simple symbol.

var _models: Node3D
var _spin := 0.0


static func make(code: String) -> ThoughtBubble:
	var b := ThoughtBubble.new()
	b._build(code)
	return b


func _build(code: String) -> void:
	var spr := Sprite3D.new()
	spr.texture = UIArt.bubble()
	spr.pixel_size = 0.0042
	spr.no_depth_test = true
	spr.render_priority = 1
	spr.shaded = false
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	spr.position = Vector3(0, 0.0, 0)
	add_child(spr)
	_models = Node3D.new()
	_models.position = Vector3(0, 0.07, 0.05)
	add_child(_models)
	if code.begins_with("r:"):
		var ids := code.substr(2).split(",", false)
		var n := ids.size()
		var sc := 0.85 if n <= 1 else 0.62
		for i in n:
			var r := Content.recipe(StringName(ids[i]))
			if r == null:
				continue
			var m := DishPlating.make_recipe_model(r)
			m.scale = Vector3.ONE * sc
			m.position = Vector3((i - (n - 1) * 0.5) * 0.24, -0.06, 0)
			m.rotation.x = deg_to_rad(38)
			_models.add_child(m)
		spr.scale = Vector3(maxf(1.0, n * 0.75), 1, 1)
		return
	var lbl := Label3D.new()
	lbl.font = load("res://art/fonts/AlfaSlabOne-Regular.ttf")
	lbl.font_size = 64
	lbl.pixel_size = 0.004
	lbl.no_depth_test = true
	lbl.render_priority = 2
	lbl.position = Vector3(0, 0.06, 0.01)
	lbl.outline_size = 0
	lbl.modulate = Pal.UI_INK
	match code:
		"think":
			lbl.text = "..."
		"order":
			lbl.text = "!"
			lbl.modulate = Pal.UI_ACCENT
		"angry":
			lbl.text = "!!"
			lbl.modulate = Pal.UI_BAD
		"pay":
			lbl.text = "$"
			lbl.modulate = Pal.UI_MONEY
		"wait":
			lbl.text = "?"
			lbl.modulate = Pal.UI_WARN
		"happy":
			lbl.text = "♥"
			lbl.modulate = Pal.DINER_RED
		_:
			lbl.text = code
	add_child(lbl)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_basis = cam.global_basis
	if _models:
		_spin += delta
		for c in _models.get_children():
			(c as Node3D).rotation.y = sin(_spin * 1.5) * 0.4
