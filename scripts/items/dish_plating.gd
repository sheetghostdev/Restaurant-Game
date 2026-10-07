class_name DishPlating
## Arranges food models on a plate so a finished dish reads at a glance:
## burgers are stacked, fries sit in a paper boat, salads are piled, pizzas
## are built up layer by layer, wings come with their dip.

const BURGER_ORDER := [&"bun", &"patty", &"cheese", &"lettuce_chopped", &"tomato_sliced"]

## What an empty drink vessel looks like here: mugs where coffee is on the
## menu, clear glasses everywhere else. Filled drinks always show their own
## vessel (see vessel_key), so soda never looks like hot chocolate.
static var cup := &"mug"


static func set_format(f: RestaurantFormatDef) -> void:
	cup = &"mug" if f == null or f.menu.has(&"coffee") or f.menu.has(&"latte") else &"glass"


static func cup_word(plural := false) -> String:
	if cup == &"glass":
		return "Glasses" if plural else "Glass"
	return "Mugs" if plural else "Mug"


## The model for a single drink vessel holding `contents`: a pint for beer,
## a tall iced glass for soda, a mug for coffee and milk, otherwise the
## restaurant's empty cup.
static func vessel_key(contents: Array, dirty := false) -> StringName:
	var ids := []
	for c in contents:
		ids.push_back(c["id"])
	if ids.has(&"beer"):
		return &"beer_pint"
	if ids.has(&"soda"):
		return &"soda_glass"
	if not ids.is_empty():
		return &"mug"
	return StringName(String(cup) + ("_dirty" if dirty else ""))


static func build(dish: DishItem, parent: Node3D, parts: Array[Node3D]) -> void:
	var ids := dish.content_ids()
	if ids.has(&"dough"):
		_pizza(dish, parent, parts)
	elif ids.has(&"wings"):
		_wings(dish, parent, parts)
	elif ids.has(&"bun"):
		_burger(dish, parent, parts)
	elif ids.has(&"fries"):
		_fries(dish, parent, parts)
	elif ids.has(&"lettuce_chopped") or ids.has(&"tomato_sliced"):
		_salad(dish, parent, parts)
	else:
		_generic(dish, parent, parts)


static func _add(parent: Node3D, parts: Array[Node3D], key: StringName, pos: Vector3, content: Dictionary, yaw := 0.0, scl := 1.0) -> Node3D:
	var n := Models.instance(key)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scl
	parent.add_child(n)
	if not content.is_empty():
		n.set_meta(&"content", content)
		parts.push_back(n)
	return n


static func _find(dish: DishItem, id: StringName) -> Dictionary:
	for c in dish.contents:
		if c["id"] == id:
			return c
	return {}


static func _burger(dish: DishItem, parent: Node3D, parts: Array[Node3D]) -> void:
	var y := 0.03
	_add(parent, parts, &"bun_bottom", Vector3(0, y, 0), _find(dish, &"bun"))
	y += 0.045
	for id in BURGER_ORDER:
		if id == &"bun":
			continue
		var c := _find(dish, id)
		if c.is_empty():
			continue
		match id:
			&"patty":
				_add(parent, parts, &"patty", Vector3(0, y, 0), c, 0.3)
				y += 0.05
			&"cheese":
				_add(parent, parts, &"cheese", Vector3(0, y, 0), c)
				y += 0.016
			&"lettuce_chopped":
				var n := _add(parent, parts, &"lettuce_chopped", Vector3(0, y - 0.01, 0), c, 0.0, 1.25)
				n.scale.y = 0.5
				y += 0.025
			&"tomato_sliced":
				_add(parent, parts, &"tomato_sliced", Vector3(0, y, 0), c, 0.5, 1.1)
				y += 0.03
	_add(parent, parts, &"bun_top", Vector3(0, y, 0), _find(dish, &"bun"))
	# Other things (e.g. fries) on the side
	for c in dish.contents:
		if not BURGER_ORDER.has(c["id"]):
			_add(parent, parts, Content.item(c["id"]).model, Vector3(0.12, 0.03, 0.08), c, 0.0, 0.7)


static func _fries(dish: DishItem, parent: Node3D, parts: Array[Node3D]) -> void:
	_add(parent, parts, &"fry_boat", Vector3(0, 0.03, 0), {})
	_add(parent, parts, &"potato_cut", Vector3(0, 0.045, 0), _find(dish, &"fries"), 0.2, 1.1)


static func _salad(dish: DishItem, parent: Node3D, parts: Array[Node3D]) -> void:
	var l := _find(dish, &"lettuce_chopped")
	if not l.is_empty():
		_add(parent, parts, &"lettuce_chopped", Vector3(0, 0.03, 0), l, 0.0, 1.35)
	var t := _find(dish, &"tomato_sliced")
	if not t.is_empty():
		_add(parent, parts, &"tomato_sliced", Vector3(0.02, 0.07 if not l.is_empty() else 0.03, 0.0), t, 0.8)


## A pizza baked on the plate: crust, sauce, cheese and toppings all take the
## dough's bake colour, so you can see it go from pale to golden to burnt.
static func _pizza(dish: DishItem, parent: Node3D, parts: Array[Node3D]) -> void:
	var dough := _find(dish, &"dough")
	_add(parent, parts, &"pizza_base", Vector3(0, 0.03, 0), dough)
	if not _find(dish, &"sauce").is_empty():
		_add(parent, parts, &"pizza_sauce", Vector3(0, 0.052, 0), dough)
	if not _find(dish, &"cheese").is_empty():
		_add(parent, parts, &"pizza_cheese", Vector3(0, 0.058, 0), dough)
	if not _find(dish, &"pepperoni").is_empty():
		_add(parent, parts, &"pizza_pepperoni", Vector3(0, 0.064, 0), dough)
	if not _find(dish, &"mushroom_sliced").is_empty():
		_add(parent, parts, &"pizza_mushrooms", Vector3(0, 0.064, 0), dough, 0.4)


static func _wings(dish: DishItem, parent: Node3D, parts: Array[Node3D]) -> void:
	_add(parent, parts, &"wings", Vector3(-0.03, 0.03, 0.0), _find(dish, &"wings"))
	var dip := _find(dish, &"dip")
	if not dip.is_empty():
		_add(parent, parts, &"dip", Vector3(0.12, 0.03, 0.06), dip)


static func _generic(dish: DishItem, parent: Node3D, parts: Array[Node3D]) -> void:
	var n := dish.contents.size()
	for k in n:
		var c: Dictionary = dish.contents[k]
		var d := Content.item(c["id"])
		if d == null:
			continue
		var a := TAU * k / maxf(n, 1)
		var off := Vector3(cos(a), 0, sin(a)) * (0.07 if n > 1 else 0.0)
		_add(parent, parts, d.model, Vector3(off.x, 0.03, off.z), c, 0.0, 0.85)


## A perfectly cooked example of a recipe (for bubbles, tickets and icons).
static func make_recipe_model(r: RecipeDef) -> Node3D:
	return make_order_model(r, [])


## The exact dish an order asks for (recipe plus chosen extras), cooked just
## right: what thought bubbles and ticket pictures show.
static func make_order_model(r: RecipeDef, extras: Array) -> Node3D:
	var root := Node3D.new()
	var contents := []
	for id in r.required + extras:
		var d := Content.item(id)
		var ck := 0.0
		if d and d.cook_profile:
			var p := d.cook_profile
			var i := p.perfect_stage
			var lo := 0.0 if i == 0 else p.stage_ends[i - 1]
			ck = (lo + p.stage_ends[i]) * 0.5
		contents.push_back({"id": id, "ck": ck})
	var parts: Array[Node3D] = []
	if r.container == "mug":
		var key := vessel_key(contents)
		root.add_child(Models.instance(key))
		if key == &"mug":
			fill_mug(contents, root, parts)
	else:
		root.add_child(Models.instance(&"plate"))
		var fake := DishItem.new()
		fake.contents = contents
		build(fake, root, parts)
		fake.free()
	return root


## The drink in a mug, just above the mug's cap: coffee (coloured by how far
## it brewed), latte, or milk waiting for its coffee. (Beer and soda have
## their own glasses.)
static func fill_mug(contents: Array, parent: Node3D, parts: Array[Node3D]) -> void:
	var ids := []
	var coffee := {}
	for c in contents:
		ids.push_back(c["id"])
		if c["id"] == &"coffee":
			coffee = c
	var key := &""
	if ids.has(&"beer"):
		key = &"beer_fill"
	elif ids.has(&"soda"):
		key = &"soda_fill"
	elif ids.has(&"coffee") and ids.has(&"milk"):
		key = &"latte_fill"
	elif ids.has(&"coffee"):
		key = &"coffee_fill"
	elif ids.has(&"milk"):
		key = &"milk_fill"
	if key == &"":
		return
	var fill := Models.instance(key)
	fill.position = Vector3(0, 0.122, 0)
	parent.add_child(fill)
	if key == &"coffee_fill" and not coffee.is_empty():
		fill.set_meta(&"content", coffee)
		parts.push_back(fill)


## Applies cooking colours to every part tagged with a "content" meta. Call it
## after the model is in the scene tree (instance uniforms need a live instance).
static func apply_colors(root: Node) -> void:
	if root.has_meta(&"content"):
		var c: Dictionary = root.get_meta(&"content", {})
		var d := Content.item(c.get("id", &""))
		if d and d.cook_profile:
			var col := d.cook_profile.color_at(c.get("ck", 0.0))
			for mi in Item._mesh_instances(root):
				mi.set_instance_shader_parameter(&"mult", Vector3(col.r, col.g, col.b))
	for ch in root.get_children():
		apply_colors(ch)
