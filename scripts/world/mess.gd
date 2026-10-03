class_name Mess
extends Entity
## Physical mess on the floor: crumbs, spills (slippery!), litter, broken dishes.
## Clean with the mop. Health inspectors notice.

var amount := 1.0
var _model: Node3D
var _water: MeshInstance3D


func get_kind() -> StringName:
	return &"mess"


func _ready() -> void:
	add_to_group(&"messes")
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	match def_id:
		&"spill":
			_water = MeshInstance3D.new()
			var b := MeshBuilder.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = net_id
			var pts := PackedVector2Array()
			for k in 14:
				var a := TAU * k / 14.0
				var r := 0.42 * rng.randf_range(0.7, 1.15)
				pts.push_back(Vector2(cos(a) * r, sin(a) * r))
			b.extrude(pts, 0.0, 0.01, Color(1, 1, 1))
			_water.mesh = b.commit()
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/water.gdshader")
			_water.material_override = m
			_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_water)
		&"trash":
			_model = Models.instance(&"mess_trash")
			add_child(_model)
		&"shards":
			_model = Models.instance(&"mess_shards")
			_model.scale = Vector3.ONE * 1.4
			add_child(_model)
		_:
			_model = Models.instance(&"crumbs")
			_model.scale = Vector3.ONE * 1.3
			add_child(_model)
	rotation.y = float(net_id % 7)


func is_slippery() -> bool:
	return def_id == &"spill"


func target_point() -> Vector3:
	return global_position


func display_name() -> String:
	match def_id:
		&"spill": return "Spill (slippery!)"
		&"trash": return "Litter"
		&"shards": return "Broken dishes"
	return "Crumbs"


## Returns true when fully cleaned.
func clean(delta: float) -> bool:
	amount -= delta * 0.9
	scale = Vector3.ONE * clampf(0.35 + amount * 0.65, 0.35, 1.0)
	mark_dirty()
	return amount <= 0.0


func get_state() -> Dictionary:
	return {"a": snappedf(amount, 0.05)}


func set_state(d: Dictionary) -> void:
	amount = d.get("a", 1.0)
	if is_inside_tree():
		scale = Vector3.ONE * clampf(0.35 + amount * 0.65, 0.35, 1.0)
