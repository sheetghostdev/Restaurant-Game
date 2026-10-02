extends Node
## Dev tool: writes the default content as .tres resources under res://resources.
## The .tres files are the source of truth for designers (edit them in the
## inspector); this seed exists to bootstrap / reset the default content set.
## Run: godot --headless --path . res://tools/dev/content_seed.tscn

const R := "res://resources"


func _ready() -> void:
	_items()
	_supplies()
	_recipes()
	_fixtures()
	_customers()
	_rooms()
	_expansions()
	_staff()
	_upgrades()
	_events()
	_formats()
	_locations()
	print("Content seed written.")
	get_tree().quit()


func _save(r: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(r, path)
	if err != OK:
		printerr("Failed to save ", path, " ", err)


# -----------------------------------------------------------------------------

func _cook(heat: StringName, rate: float, names: Array, ends: Array, quality: Array, colors: Array, perfect: int, smoke: float, fire: float) -> CookProfile:
	var c := CookProfile.new()
	c.heat = heat
	c.rate = rate
	c.stage_names = PackedStringArray(names)
	c.stage_ends = PackedFloat32Array(ends)
	c.stage_quality = PackedFloat32Array(quality)
	c.stage_colors = PackedColorArray(colors)
	c.perfect_stage = perfect
	c.smoke_from = smoke
	c.fire_at = fire
	return c


func _item(id: String, name: String, cls: String, model: String, color: Color, tags: Array, opts := {}) -> void:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.display_name = name
	d.item_class = cls
	d.model = StringName(model)
	d.color = color
	d.tags = PackedStringArray(tags)
	for k in opts:
		d.set(k, opts[k])
	_save(d, "%s/ingredients/%s.tres" % [R, id])


func _items() -> void:
	var grill := _cook(&"grill", 1.0 / 14.0,
		["Raw", "Rare", "Medium", "Well Done", "Overcooked", "Burnt"],
		[0.35, 0.6, 0.9, 1.15, 1.45, 99.0],
		[0.0, 0.7, 1.0, 0.85, 0.4, 0.0],
		[Color("e37b7e"), Color("c46a5a"), Color("8a5236"), Color("6e4128"), Color("4a2d1e"), Color("2b211d")],
		2, 1.15, 1.9)
	var fryer := _cook(&"fryer", 1.0 / 11.0,
		["Raw", "Soggy", "Crispy", "Overdone", "Burnt"],
		[0.4, 0.65, 1.0, 1.3, 99.0],
		[0.0, 0.55, 1.0, 0.45, 0.0],
		[Color("f6efd8"), Color("f0d9a0"), Color("f2c14e"), Color("c98a35"), Color("5a3a20")],
		2, 1.0, 1.8)
	var brew := _cook(&"brew", 1.0 / 5.0,
		["Weak", "Just Right", "Strong", "Overflowing"],
		[0.55, 1.0, 1.35, 99.0],
		[0.5, 1.0, 0.8, 0.0],
		[Color("b07a4a"), Color("5a3622"), Color("3a2016"), Color("1c120c")],
		1, 99.0, 1.6)
	_item("patty", "Beef Patty", "food", "patty", Pal.PATTY_RAW, ["grillable", "plateable", "meat"],
		{"cook_profile": grill, "unit_cost": 1.5, "perishable": true, "spoil_seconds": 260.0, "plate_layer": 1,
		"description": "Grill until medium. Keep the crate in the fridge."})
	_item("bun", "Burger Bun", "food", "bun", Pal.BUN, ["plateable", "bread"],
		{"unit_cost": 0.5, "description": "The foundation of every burger."})
	_item("lettuce", "Lettuce", "food", "lettuce_head", Pal.LETTUCE, ["choppable", "veg"],
		{"chop_into": &"lettuce_chopped", "chop_work": 2.2, "unit_cost": 0.75, "perishable": true, "spoil_seconds": 420.0,
		"description": "Chop it on a cutting board. Wilts if left out of the fridge."})
	_item("lettuce_chopped", "Chopped Lettuce", "food", "lettuce_chopped", Pal.LETTUCE, ["plateable", "prepared", "veg"],
		{"unit_cost": 0.75, "perishable": true, "spoil_seconds": 360.0, "plate_layer": 2})
	_item("tomato", "Tomato", "food", "tomato", Pal.TOMATO, ["choppable", "veg"],
		{"chop_into": &"tomato_sliced", "chop_work": 1.8, "unit_cost": 0.75, "perishable": true, "spoil_seconds": 900.0,
		"description": "Slice it for burgers and salads."})
	_item("tomato_sliced", "Tomato Slices", "food", "tomato_sliced", Pal.TOMATO, ["plateable", "prepared", "veg"],
		{"unit_cost": 0.75, "perishable": true, "spoil_seconds": 600.0, "plate_layer": 3})
	_item("potato", "Potato", "food", "potato", Pal.POTATO, ["choppable", "veg"],
		{"chop_into": &"fries", "chop_work": 2.2, "unit_cost": 0.5, "description": "Cut into fries, then fry until crispy."})
	_item("fries", "Fries", "food", "potato_cut", Pal.FRIES, ["fryable", "plateable", "prepared"],
		{"cook_profile": fryer, "unit_cost": 0.5})
	_item("coffee_beans", "Coffee Beans", "food", "coffee_beans", Pal.BEANS, ["beans"],
		{"unit_cost": 0.8, "description": "Pour into the coffee machine's hopper (10 cups per bag)."})
	_item("coffee", "Coffee", "food", "coffee_fill", Pal.COFFEE, ["drink"],
		{"cook_profile": brew, "unit_cost": 0.8})
	_item("dishware", "Plate", "dish", "plate", Pal.PLATE, ["dish"], {})
	_item("crate", "Crate", "crate", "crate", Pal.CRATE, ["crate"],
		{"heavy": true, "blocks_when_dropped": true})
	_item("package", "Boxed Equipment", "package", "flatpack", Pal.CARDBOARD, ["package"],
		{"heavy": true, "blocks_when_dropped": true})
	_item("extinguisher", "Fire Extinguisher", "tool", "extinguisher", Pal.FIRE_RED, ["extinguisher", "tool"],
		{"description": "Hold USE to spray at a fire."})
	_item("mop", "Mop", "tool", "mop", Color("e8e2d0"), ["mop", "tool"],
		{"description": "Hold USE to clean spills and crumbs."})
	_item("trash_bag", "Trash Bag", "trash", "trash_bag", Color("39403f"), ["trash"],
		{"heavy": true, "blocks_when_dropped": true})


func _supply(id: String, name: String, item: String, qty: int, price: float, container: String, cold: bool, order: int, desc: String) -> void:
	var s := SupplyDef.new()
	s.id = StringName(id)
	s.display_name = name
	s.item_id = StringName(item)
	s.quantity = qty
	s.price = price
	s.container = container
	s.needs_cold = cold
	s.default_order = order
	s.description = desc
	_save(s, "%s/supplies/%s.tres" % [R, id])


func _supplies() -> void:
	_supply("supply_beef", "Beef Patties", "patty", 12, 18.0, "crate_cold", true, 1, "A chilled tub of 12 patties.")
	_supply("supply_buns", "Burger Buns", "bun", 12, 6.0, "carton", false, 1, "A carton of 12 soft buns.")
	_supply("supply_potatoes", "Potatoes", "potato", 10, 5.0, "sack", false, 1, "A sack of 10 potatoes.")
	_supply("supply_lettuce", "Lettuce", "lettuce", 8, 6.0, "crate", true, 1, "8 heads of crisp lettuce.")
	_supply("supply_tomatoes", "Tomatoes", "tomato", 8, 6.0, "crate", false, 1, "8 ripe tomatoes.")
	_supply("supply_coffee", "Coffee Beans", "coffee_beans", 4, 8.0, "carton", false, 1, "4 bags of beans (10 cups each).")


func _recipe(id: String, name: String, cont: String, req: Array, opt: Array, price: float, weight: float, eat: float, plating: String, color: Color, steps: Array, day := 1) -> void:
	var r := RecipeDef.new()
	r.id = StringName(id)
	r.display_name = name
	r.container = cont
	var rq: Array[StringName] = []
	for x in req:
		rq.push_back(StringName(x))
	var op: Array[StringName] = []
	for x in opt:
		op.push_back(StringName(x))
	r.required = rq
	r.optional = op
	r.price = price
	r.menu_weight = weight
	r.eat_time = eat
	r.plating = plating
	r.icon_color = color
	r.prep_steps = PackedStringArray(steps)
	r.unlock_day = day
	_save(r, "%s/recipes/%s.tres" % [R, id])


func _recipes() -> void:
	_recipe("burger", "Classic Burger", "plate", ["bun", "patty"], ["lettuce_chopped", "tomato_sliced"], 11.0, 1.3, 12.0, "burger", Pal.BUN,
		["Grill a patty until medium", "Put a bun on a plate", "Add the patty", "(Optional) add lettuce or tomato"])
	_recipe("deluxe_burger", "Garden Deluxe", "plate", ["bun", "patty", "lettuce_chopped", "tomato_sliced"], [], 15.0, 0.7, 14.0, "burger", Pal.LETTUCE,
		["Grill a patty", "Chop lettuce, slice tomato", "Stack everything on a bun"], 2)
	_recipe("fries", "Crispy Fries", "plate", ["fries"], [], 5.0, 1.0, 8.0, "fries", Pal.FRIES,
		["Cut a potato on the cutting board", "Fry until crispy", "Plate it"])
	_recipe("salad", "Garden Salad", "plate", ["lettuce_chopped", "tomato_sliced"], [], 8.0, 0.6, 9.0, "salad", Pal.LETTUCE,
		["Chop lettuce", "Slice a tomato", "Plate both"])
	_recipe("coffee", "Coffee", "mug", ["coffee"], [], 4.0, 1.0, 6.0, "drink", Pal.COFFEE,
		["Put a clean mug under the coffee machine", "Take it when it's just right"])


func _fixture(id: String, name: String, scene: String, cat: String, price: float, desc: String, opts := {}) -> void:
	var f := FixtureDef.new()
	f.id = StringName(id)
	f.display_name = name
	f.scene = load(scene)
	f.category = cat
	f.price = price
	f.description = desc
	f.model = StringName(id)
	for k in opts:
		f.set(k, opts[k])
	_save(f, "%s/equipment/%s.tres" % [R, id])


func _fixtures() -> void:
	var A := "res://scenes/appliances/"
	var F := "res://scenes/furniture/"
	var M := "res://scenes/automation/"
	_fixture("counter", "Counter", F + "counter.tscn", "furniture", 30.0, "A sturdy prep surface. Put anything on it.")
	_fixture("pass_counter", "Pass Counter", F + "pass_counter.tscn", "furniture", 55.0, "A steel counter with a heat lamp gantry — the classic 'order up' spot.")
	_fixture("cutting_board", "Cutting Board", A + "cutting_board.tscn", "appliance", 40.0, "Hold USE to chop lettuce, tomatoes and potatoes.")
	_fixture("grill", "Flat-top Grill", A + "grill.tscn", "appliance", 140.0, "Cooks patties. Watch the colour — and the smoke.", {"flammable": true, "can_break": true})
	_fixture("fryer", "Deep Fryer", A + "fryer.tscn", "appliance", 160.0, "Turns cut potatoes into crispy fries. Grease fires happen.", {"flammable": true, "can_break": true})
	_fixture("coffee_machine", "Coffee Machine", A + "coffee_machine.tscn", "appliance", 120.0, "Brews into clean mugs automatically. Refill the bean hopper.", {"can_break": true})
	_fixture("fridge", "Glass Fridge", A + "fridge.tscn", "storage", 150.0, "Keeps one crate cold. Beef and lettuce spoil without it.", {"can_break": true, "collision_height": 1.9})
	_fixture("sink", "Sink", A + "sink.tscn", "appliance", 70.0, "Drop dirty dishes in and hold USE to scrub.")
	_fixture("dishwasher", "Hood Dishwasher", A + "dishwasher.tscn", "appliance", 220.0, "Load up to 10 dishes and press USE. Sometimes breaks down.", {"can_break": true, "collision_height": 1.4})
	_fixture("trash_bin", "Trash Bin", A + "trash_bin.tscn", "service", 25.0, "Throw away food or scrape plates. Empty it when full.", {"collision_height": 0.75})
	_fixture("dumpster", "Dumpster", A + "dumpster.tscn", "service", 60.0, "Outdoor bin for trash bags, empty crates and spoiled stock.", {"allowed_outdoors": true, "collision_height": 1.1})
	_fixture("plate_rack", "Plate Rack", F + "plate_rack.tscn", "service", 45.0, "Holds clean plates. Comes with 4 plates.")
	_fixture("mug_rack", "Mug Rack", F + "mug_rack.tscn", "service", 35.0, "Holds clean mugs. Comes with 4 mugs.")
	_fixture("shelf", "Storage Shelf", F + "shelf.tscn", "storage", 35.0, "Holds one crate where everyone can see it.", {"collision_height": 0.78})
	_fixture("cold_shelf", "Steel Shelf", F + "cold_shelf.tscn", "storage", 45.0, "Wire shelving for walk-in coolers. Anything in a cold room stays fresh.", {"collision_height": 0.78})
	_fixture("table", "Dining Table", F + "table.tscn", "furniture", 50.0, "Push tables together to seat bigger groups.", {"collision_height": 0.72, "allowed_outdoors": true})
	_fixture("chair", "Diner Chair", F + "chair.tscn", "furniture", 20.0, "Face it toward a table to add a seat.", {"blocks_movement": false, "allowed_outdoors": true})
	_fixture("terminal", "Manager's Desk", F + "terminal.tscn", "service", 0.0, "Order supplies, equipment and staff.", {"purchasable": false})
	_fixture("open_sign", "Open Sign", F + "open_sign.tscn", "service", 0.0, "Hold USE to open the restaurant.", {"purchasable": false, "collision_height": 1.6})
	_fixture("register", "Cash Register", F + "register.tscn", "service", 80.0, "Ka-ching. Purely for the vibes (and a spare counter).")
	_fixture("plant_pot", "Potted Plant", F + "plant_pot.tscn", "decor", 25.0, "Makes the dining room a little nicer.", {"ambience": 0.02, "collision_height": 1.0, "allowed_outdoors": true})
	_fixture("jukebox", "Jukebox", F + "jukebox.tscn", "decor", 180.0, "Customers wait a bit more patiently.", {"ambience": 0.05, "collision_height": 1.2, "unlock_day": 2})
	_fixture("extinguisher_station", "Extinguisher Stand", F + "extinguisher_station.tscn", "service", 60.0, "Holds a fire extinguisher, which slowly refills here.", {"collision_height": 1.8})
	_fixture("mop_station", "Mop Bucket", F + "mop_station.tscn", "service", 30.0, "Home of the mop.", {"collision_height": 0.6})
	_fixture("conveyor", "Conveyor Belt", M + "conveyor.tscn", "automation", 70.0, "Moves items toward the fixture it faces. Chain them!", {"collision_height": 0.72, "unlock_day": 2})
	_fixture("grabber", "Grabber Arm", M + "grabber.tscn", "automation", 120.0, "Takes one item from behind and puts it in front. Pulls single ingredients out of crates.", {"collision_height": 0.66, "unlock_day": 2, "can_break": true})
	_fixture("auto_chopper", "Auto-Chopper", A + "auto_chopper.tscn", "automation", 260.0, "Slowly chops whatever is placed on it, no hands needed.", {"unlock_day": 3, "can_break": true})


func _arch(id: String, name: String, opts: Dictionary) -> void:
	var a := CustomerArchetype.new()
	a.id = StringName(id)
	a.display_name = name
	for k in opts:
		a.set(k, opts[k])
	_save(a, "%s/customers/%s.tres" % [R, id])


func _customers() -> void:
	_arch("regular_folks", "Townsfolk", {"group_min": 1, "group_max": 2, "patience": 1.0, "drink_chance": 0.35,
		"mess": 0.12, "spawn_weight": 1.0, "description": "Ordinary locals. Easygoing."})
	_arch("family", "Family", {"group_min": 3, "group_max": 4, "child_chance": 0.55, "patience": 0.85, "drink_chance": 0.3,
		"recipe_weights": {"fries": 1.8, "burger": 1.3, "salad": 0.6, "deluxe_burger": 0.5}, "mess": 0.75, "tip": 0.9, "spawn_weight": 0.55,
		"hour_weights": {12: 1.2, 13: 1.0, 17: 1.4, 18: 1.6, 19: 1.2, -1: 0.45}, "description": "Big tables, lots of fries, lots of crumbs."})
	_arch("work_crew", "Work Crew", {"group_min": 2, "group_max": 4, "patience": 0.75, "dishes_min": 1, "dishes_max": 2, "drink_chance": 0.5,
		"recipe_weights": {"burger": 2.0, "fries": 1.6, "salad": 0.25, "deluxe_burger": 1.0}, "tip": 0.8, "mess": 0.3, "spawn_weight": 0.8,
		"hour_weights": {11: 1.0, 12: 2.3, 13: 1.7, -1: 0.25}, "accessory": &"hard_hat",
		"outfit_colors": PackedColorArray([Color("f28c28"), Color("4f6d8f"), Color("7a8f5a")]), "description": "Hungry and in a hurry. Lunchtime regulars."})
	_arch("business", "Business Lunch", {"group_min": 2, "group_max": 3, "patience": 0.95, "drink_chance": 0.9, "spend": 1.3, "tip": 1.4,
		"eat_speed": 0.8, "recipe_weights": {"salad": 1.6, "deluxe_burger": 1.5, "fries": 0.5}, "min_day": 2, "spawn_weight": 0.5,
		"hour_weights": {12: 1.6, 13: 1.6, 14: 1.0, -1: 0.35}, "accessory": &"tie", "description": "Coffee, salads and generous tips. They linger."})
	_arch("date", "Date Night", {"group_min": 2, "group_max": 2, "patience": 1.1, "drink_chance": 0.6, "eat_speed": 0.75, "tip": 1.3,
		"min_day": 3, "spawn_weight": 0.5, "hour_weights": {18: 2.0, 19: 2.2, 20: 2.0, -1: 0.25}, "accessory": &"bow", "mess": 0.05,
		"description": "Two people, no rush, big tips if it goes well."})
	_arch("tourists", "Tourists", {"group_min": 2, "group_max": 4, "patience": 1.2, "dishes_min": 1, "dishes_max": 2, "drink_chance": 0.5,
		"min_day": 2, "spawn_weight": 0.45, "hour_weights": {14: 1.6, 15: 1.8, 16: 1.6, -1: 0.6}, "accessory": &"camera",
		"description": "Slow to order, curious about everything."})
	_arch("traveler", "Tired Traveler", {"group_min": 1, "group_max": 1, "patience": 0.6, "drink_chance": 0.85, "eat_speed": 1.4,
		"recipe_weights": {"fries": 1.5, "burger": 1.2, "salad": 0.4}, "spawn_weight": 0.45, "accessory": &"backpack",
		"description": "Wants something simple, fast."})
	_arch("critic", "Food Critic", {"group_min": 1, "group_max": 1, "patience": 0.9, "drink_chance": 0.7, "strictness": 0.35,
		"reputation_weight": 4.0, "tip": 2.0, "min_reputation": 2.5, "min_day": 3, "spawn_weight": 0.12, "accessory": &"beret",
		"description": "Rare. Notices everything. One review can change your week."})


func _room(id: String, name: String, style: String, a: Color, b: Color, wall: Color, opts := {}) -> void:
	var r := RoomTypeDef.new()
	r.id = StringName(id)
	r.display_name = name
	r.floor_style = style
	r.floor_a = a
	r.floor_b = b
	r.wall_color = wall
	for k in opts:
		r.set(k, opts[k])
	_save(r, "%s/rooms/%s.tres" % [R, id])


func _rooms() -> void:
	_room("dining", "Dining Room", "planks", Color("d2a779"), Color("b98a5e"), Pal.PLASTER, {"customer_area": true, "light_color": Color("ffd9a8")})
	_room("kitchen", "Kitchen", "tile_checker", Pal.TILE_CREAM, Pal.TILE_SAGE, Color("eef0e8"), {"light_color": Color("fff1dc")})
	_room("storage", "Storage", "concrete", Pal.CONCRETE, Pal.CONCRETE_DARK, Pal.PLASTER_SHADE, {"light_color": Color("ffe9c9")})
	_room("loading", "Loading Dock", "loading", Color("b8b4aa"), Color("a8a49a"), Pal.FACADE, {"outdoor": true})
	_room("cooler", "Walk-in Cooler", "cold_tile", Pal.COLD_TILE, Color("b7d3de"), Color("dfeef3"), {"cold": true, "light_color": Color("d9f0ff")})
	_room("patio", "Patio", "patio", Color("cdb79a"), Color("b9a283"), Pal.FACADE, {"outdoor": true, "customer_area": true})


func _expansion(id: String, name: String, type: String, rect: Rect2i, price: float, doors: Array, fixtures: Array, desc: String) -> void:
	var e := ExpansionDef.new()
	e.id = StringName(id)
	e.display_name = name
	e.room_type = StringName(type)
	e.rect = rect
	e.price = price
	var d: Array[Vector4i] = []
	for x in doors:
		d.push_back(x)
	e.doors = d
	var f: Array[Dictionary] = []
	for x in fixtures:
		f.push_back(x)
	e.starter_fixtures = f
	e.description = desc
	_save(e, "%s/upgrades/expansion_%s.tres" % [R, id])


func _expansions() -> void:
	_expansion("dining_annex", "Dining Annex", "dining", Rect2i(0, -5, 9, 5), 450.0,
		[Vector4i(3, -1, 3, 0), Vector4i(6, -1, 6, 0)],
		[{"def": "table", "cell": Vector2i(2, -3), "rot": 0}, {"def": "chair", "cell": Vector2i(2, -4), "rot": 0}, {"def": "chair", "cell": Vector2i(2, -2), "rot": 2},
		{"def": "table", "cell": Vector2i(6, -3), "rot": 0}, {"def": "chair", "cell": Vector2i(6, -4), "rot": 0}, {"def": "chair", "cell": Vector2i(6, -2), "rot": 2}],
		"More tables behind the dining room. More guests, longer walks.")
	_expansion("dish_room", "Dish Room", "kitchen", Rect2i(9, -4, 7, 4), 380.0,
		[Vector4i(12, -1, 12, 0)],
		[{"def": "sink", "cell": Vector2i(10, -4), "rot": 0}],
		"A back room just for washing up — keeps the line clear.")
	_expansion("walk_in_cooler", "Walk-in Cooler", "cooler", Rect2i(16, -4, 4, 4), 520.0,
		[Vector4i(17, -1, 17, 0)],
		[{"def": "cold_shelf", "cell": Vector2i(16, -4), "rot": 0}, {"def": "cold_shelf", "cell": Vector2i(17, -4), "rot": 0}, {"def": "cold_shelf", "cell": Vector2i(18, -4), "rot": 0}],
		"Everything stored inside stays fresh. No more fridge Tetris.")
	_expansion("patio", "Sidewalk Patio", "patio", Rect2i(-5, 2, 5, 7), 300.0,
		[Vector4i(-1, 4, 0, 4)],
		[{"def": "table", "cell": Vector2i(-3, 4), "rot": 0}, {"def": "chair", "cell": Vector2i(-3, 3), "rot": 0}, {"def": "chair", "cell": Vector2i(-3, 5), "rot": 2}],
		"Outdoor seating off the dining room. Customers love the sun.")


func _staff_def(id: String, name: String, role: String, hire: float, wage: float, speed: float, uniform: Color, day: int, desc: String) -> void:
	var s := StaffDef.new()
	s.id = StringName(id)
	s.display_name = name
	s.role = StringName(role)
	s.hire_cost = hire
	s.daily_wage = wage
	s.work_speed = speed
	s.uniform = uniform
	s.unlock_day = day
	s.description = desc
	_save(s, "%s/staff/%s.tres" % [R, id])


func _staff() -> void:
	_staff_def("dish_hand", "Dish Hand", "dishwasher", 60.0, 35.0, 0.6, Color("6a8fa0"), 1, "Washes dishes at the sink, runs the dishwasher and puts clean plates away.")
	_staff_def("busser", "Busser", "busser", 60.0, 30.0, 0.7, Color("8f7a5a"), 2, "Clears dirty tables and wipes up crumbs.")
	_staff_def("stocker", "Stocker", "stocker", 70.0, 30.0, 0.7, Color("7a8f5a"), 2, "Carries deliveries from the dock onto shelves (cold stuff first).")
	_staff_def("waiter", "Waiter", "server", 80.0, 40.0, 0.8, Color("8c5a7a"), 3, "Takes orders as soon as tables are ready; buses tables in between.")


func _upgrade(id: String, name: String, price: float, effect: String, amount: float, repeatable: bool, desc: String, day := 1) -> void:
	var u := UpgradeDef.new()
	u.id = StringName(id)
	u.display_name = name
	u.price = price
	u.effect = StringName(effect)
	u.amount = amount
	u.repeatable = repeatable
	u.description = desc
	u.unlock_day = day
	_save(u, "%s/upgrades/%s.tres" % [R, id])


func _upgrades() -> void:
	_upgrade("more_plates", "Six More Plates", 40.0, "extra_plates", 6, true, "Added to your plate rack. More plates, more buffer before washing up.")
	_upgrade("more_mugs", "Four More Mugs", 25.0, "extra_mugs", 4, true, "Added to your mug rack.")


func _event(id: String, name: String, kind: String, chance: float, min_day: int, params: Dictionary, warning := "", desc := "") -> void:
	var e := EventDef.new()
	e.id = StringName(id)
	e.display_name = name
	e.kind = kind
	e.chance_per_day = chance
	e.min_day = min_day
	e.params = params
	e.warning_text = warning
	e.description = desc
	_save(e, "%s/events/%s.tres" % [R, id])


func _events() -> void:
	_event("grease_fire", "Grease Fire", "disaster", 0.3, 2, {}, "", "A grill or fryer bursts into flames.")
	_event("dishwasher_breakdown", "Dishwasher Breakdown", "disaster", 0.35, 2, {}, "", "Wash by hand until it's repaired.")
	_event("fridge_failure", "Fridge Failure", "disaster", 0.2, 3, {}, "", "A fridge stops cooling; stock starts to warm.")
	_event("machine_breakdown", "Equipment Breakdown", "disaster", 0.18, 4, {}, "", "A cooking appliance breaks mid-service.")
	_event("pipe_leak", "Pipe Leak", "disaster", 0.2, 3, {}, "", "Water on the kitchen floor.")
	_event("equipment_jam", "Conveyor Jam", "disaster", 0.3, 2, {}, "", "Automation stops until someone clears it.")
	_event("surprise_delivery", "Surprise Delivery", "delivery", 0.25, 2, {}, "The supplier might drop off extra stock mid-shift.")
	_event("health_inspection", "Health Inspection", "inspection", 0.15, 3, {}, "A health inspector is visiting the neighbourhood.")
	_event("office_lunch", "Office Lunch Rush", "crowd", 0.25, 2, {"hours": [12, 13], "mult": 1.5}, "Offices nearby: big lunch crowd expected.")
	_event("street_festival", "Street Festival", "crowd", 0.15, 3, {"hours": [18, 19, 20], "mult": 1.7}, "Street festival tonight! Huge dinner rush.")
	_event("rainy_day", "Rainy Day", "crowd", 0.15, 2, {"all_day": 0.75}, "Rain in the forecast: a quieter day.")
	_event("big_game", "Big Game Night", "crowd", 0.12, 4, {"hours": [20], "mult": 2.2}, "The big game ends at 8pm — expect a wave.")


func _formats() -> void:
	var f := RestaurantFormatDef.new()
	f.id = &"diner"
	f.display_name = "Diner"
	f.service_style = "table"
	var menu: Array[StringName] = [&"burger", &"deluxe_burger", &"fries", &"salad", &"coffee"]
	f.menu = menu
	f.open_hour = 11
	f.close_hour = 21
	f.service_seconds = 420.0
	f.base_groups = 8.0
	f.hourly_demand = {11: 0.6, 12: 2.0, 13: 1.7, 14: 0.8, 15: 0.6, 16: 0.7, 17: 1.2, 18: 2.0, 19: 1.8, 20: 0.8}
	var archs: Array[StringName] = [&"regular_folks", &"family", &"work_crew", &"business", &"date", &"tourists", &"traveler", &"critic"]
	f.archetypes = archs
	f.description = "Classic table service: burgers, fries, salads and bottomless coffee."
	_save(f, "%s/formats/diner.tres" % R)


func _locations() -> void:
	var l := LocationDef.new()
	l.id = &"main_street"
	l.display_name = "Main Street"
	l.layout_path = "res://data/layouts/main_street.json"
	l.demand = 1.0
	var ex: Array[StringName] = [&"dining_annex", &"dish_room", &"walk_in_cooler", &"patio"]
	l.expansions = ex
	l.description = "A small-town storefront with room to grow out back."
	_save(l, "%s/locations/main_street.tres" % R)
