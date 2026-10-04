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
	# Cooking is quick with a generous "perfect" window: the challenge is
	# juggling, not waiting on one patty.
	var grill := _cook(&"grill", 1.0 / 9.0,
		["Raw", "Rare", "Medium", "Well Done", "Overcooked", "Burnt"],
		[0.3, 0.55, 0.95, 1.2, 1.5, 99.0],
		[0.0, 0.7, 1.0, 0.85, 0.4, 0.0],
		[Color("e37b7e"), Color("c46a5a"), Color("8a5236"), Color("6e4128"), Color("4a2d1e"), Color("2b211d")],
		2, 1.2, 2.0)
	var fryer := _cook(&"fryer", 1.0 / 8.0,
		["Raw", "Soggy", "Crispy", "Overdone", "Burnt"],
		[0.35, 0.6, 1.05, 1.35, 99.0],
		[0.0, 0.55, 1.0, 0.45, 0.0],
		[Color("f6efd8"), Color("f0d9a0"), Color("f2c14e"), Color("c98a35"), Color("5a3a20")],
		2, 1.05, 1.9)
	var brew := _cook(&"brew", 1.0 / 4.0,
		["Weak", "Just Right", "Strong", "Overflowing"],
		[0.5, 1.1, 1.5, 99.0],
		[0.5, 1.0, 0.85, 0.0],
		[Color("b07a4a"), Color("5a3622"), Color("3a2016"), Color("1c120c")],
		1, 99.0, 1.9)
	_item("patty", "Beef Patty", "food", "patty", Pal.PATTY_RAW, ["grillable", "plateable", "meat"],
		{"cook_profile": grill, "unit_cost": 1.5, "perishable": true, "spoil_seconds": 260.0, "plate_layer": 1,
		"description": "Grill until medium. Keep the crate in the fridge."})
	_item("bun", "Burger Bun", "food", "bun", Pal.BUN, ["plateable", "bread"],
		{"unit_cost": 0.5, "description": "The foundation of every burger."})
	_item("lettuce", "Lettuce", "food", "lettuce_head", Pal.LETTUCE, ["choppable", "veg"],
		{"chop_into": &"lettuce_chopped", "chop_work": 1.3, "unit_cost": 0.75, "perishable": true, "spoil_seconds": 420.0, "grow_seconds": 26.0,
		"description": "Chop it on a cutting board. Wilts if left out of the fridge."})
	_item("lettuce_chopped", "Chopped Lettuce", "food", "lettuce_chopped", Pal.LETTUCE, ["plateable", "prepared", "veg"],
		{"unit_cost": 0.75, "perishable": true, "spoil_seconds": 360.0, "plate_layer": 2})
	_item("tomato", "Tomato", "food", "tomato", Pal.TOMATO, ["choppable", "veg"],
		{"chop_into": &"tomato_sliced", "chop_work": 1.1, "unit_cost": 0.75, "perishable": true, "spoil_seconds": 900.0, "grow_seconds": 24.0,
		"description": "Slice it for burgers and salads."})
	_item("tomato_sliced", "Tomato Slices", "food", "tomato_sliced", Pal.TOMATO, ["plateable", "prepared", "veg"],
		{"unit_cost": 0.75, "perishable": true, "spoil_seconds": 600.0, "plate_layer": 3})
	_item("potato", "Potato", "food", "potato", Pal.POTATO, ["choppable", "veg"],
		{"chop_into": &"fries", "chop_work": 1.3, "unit_cost": 0.5, "grow_seconds": 22.0, "description": "Cut into fries, then fry until crispy."})
	_item("fries", "Fries", "food", "potato_cut", Pal.FRIES, ["fryable", "plateable", "prepared"],
		{"cook_profile": fryer, "unit_cost": 0.5})
	_item("coffee_beans", "Coffee Beans", "food", "coffee_beans", Pal.BEANS, ["beans"],
		{"unit_cost": 0.8, "grow_seconds": 70.0, "description": "Pour into the coffee machine's hopper (10 cups per bag)."})
	_item("coffee", "Coffee", "food", "coffee_fill", Pal.COFFEE, ["drink"],
		{"cook_profile": brew, "unit_cost": 0.8, "made_from": &"coffee_beans"})
	# Coffee shop
	var pastry := _cook(&"oven", 1.0 / 8.0,
		["Raw", "Golden", "Dark", "Burnt"],
		[0.5, 1.0, 1.3, 99.0],
		[0.1, 1.0, 0.55, 0.0],
		[Color("ffffff"), Color("f0b860"), Color("c07a3a"), Color("4a3428")],
		1, 1.2, 2.0)
	_item("milk", "Milk", "food", "milk", Color("f7f5ef"), ["plateable", "dairy"],
		{"unit_cost": 0.4, "perishable": true, "spoil_seconds": 420.0,
		"description": "Pour into a clean mug, then add coffee for a latte. Keep it in the fridge."})
	_item("croissant", "Croissant", "food", "croissant", Color("e0a050"), ["ovenable", "plateable", "bread"],
		{"cook_profile": pastry, "unit_cost": 0.6, "description": "Bake in the oven until golden."})
	_item("muffin", "Muffin", "food", "muffin", Color("b07440"), ["plateable", "bread"],
		{"unit_cost": 0.6, "description": "Ready to serve: just plate it."})
	_item("jam", "Jam", "food", "jam", Color("b3263a"), ["plateable"],
		{"unit_cost": 0.2, "plate_layer": 2, "description": "A little pot of jam for croissants."})
	# Pizza parlor
	var bake := _cook(&"oven", 1.0 / 11.0,
		["Raw", "Golden", "Well Done", "Burnt"],
		[0.5, 1.0, 1.3, 99.0],
		[0.1, 1.0, 0.6, 0.0],
		[Color("ffffff"), Color("f2c47a"), Color("c08048"), Color("4a3020")],
		1, 1.25, 1.9)
	_item("dough", "Pizza Dough", "food", "dough", Color("f6efd8"), ["plateable", "bread"],
		{"cook_profile": bake, "unit_cost": 0.6,
		"description": "Put it on a plate, add sauce and cheese, then bake the whole plate in the oven."})
	_item("sauce", "Tomato Sauce", "food", "sauce", Color("c8302a"), ["plateable"],
		{"unit_cost": 0.4, "plate_layer": 1, "description": "Spread on pizza dough."})
	_item("cheese", "Cheese", "food", "cheese", Color("f2c94c"), ["plateable", "dairy"],
		{"unit_cost": 0.6, "plate_layer": 2, "perishable": true, "spoil_seconds": 540.0,
		"description": "Goes on every pizza. Keep it in the fridge."})
	_item("pepperoni", "Pepperoni", "food", "pepperoni", Color("c0453a"), ["plateable", "meat"],
		{"unit_cost": 0.5, "plate_layer": 3, "description": "A pizza topping."})
	_item("mushroom", "Mushroom", "food", "mushroom", Color("d8c8a8"), ["choppable", "veg"],
		{"chop_into": &"mushroom_sliced", "chop_work": 1.0, "unit_cost": 0.4, "grow_seconds": 20.0, "description": "Slice it for pizza."})
	_item("mushroom_sliced", "Sliced Mushrooms", "food", "mushroom_sliced", Color("d8c8a8"), ["plateable", "prepared", "veg"],
		{"unit_cost": 0.4, "plate_layer": 3})
	# Drinks poured by machines
	var pour := _cook(&"pour", 1.0 / 3.0,
		["Pouring", "Full", "Foamy", "Overflowing"],
		[0.45, 1.2, 1.55, 99.0],
		[0.5, 1.0, 0.8, 0.0],
		[Color("ffffff"), Color("ffffff"), Color("ffffff"), Color("ffffff")],
		1, 99.0, 1.6)
	_item("soda", "Soda", "food", "soda_fill", Color("7a3a2a"), ["drink"],
		{"cook_profile": pour, "unit_cost": 0.4, "made_from": &"soda_syrup"})
	_item("beer", "Beer", "food", "beer_fill", Color("e8b04a"), ["drink"],
		{"cook_profile": pour, "unit_cost": 1.2, "made_from": &"keg"})
	_item("soda_syrup", "Soda Syrup", "food", "soda_syrup", Color("8a3a2a"), ["refill"],
		{"unit_cost": 5.0, "description": "Load into the soda fountain (12 drinks per box)."})
	_item("keg", "Beer Keg", "food", "keg", Color("b8bcc4"), ["refill"],
		{"unit_cost": 13.0, "description": "Load into the beer tap (16 pints per keg)."})
	# Bar food
	var wing := _cook(&"fryer", 1.0 / 9.0,
		["Raw", "Cooking", "Crispy", "Overdone", "Burnt"],
		[0.35, 0.6, 1.05, 1.35, 99.0],
		[0.0, 0.5, 1.0, 0.45, 0.0],
		[Color("f2c8b8"), Color("e0a070"), Color("d06a32"), Color("8a4020"), Color("3a2418")],
		2, 1.0, 1.8)
	_item("wings", "Chicken Wings", "food", "wings", Color("d06a32"), ["fryable", "plateable", "meat"],
		{"cook_profile": wing, "unit_cost": 1.4, "perishable": true, "spoil_seconds": 300.0,
		"description": "Fry until crispy. Keep the crate in the fridge."})
	_item("dip", "Dip", "food", "dip", Color("f0ece4"), ["plateable"],
		{"unit_cost": 0.3, "plate_layer": 2, "description": "A pot of dip on the side of the wings."})
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
	_supply("supply_milk", "Milk", "milk", 6, 6.0, "crate_cold", true, 0, "6 cartons of milk. Keep cold.")
	_supply("supply_croissants", "Croissants", "croissant", 10, 7.0, "carton", false, 0, "10 croissants, ready to bake.")
	_supply("supply_muffins", "Muffins", "muffin", 10, 8.0, "carton", false, 0, "10 blueberry muffins.")
	_supply("supply_jam", "Jam", "jam", 12, 4.0, "carton", false, 0, "12 little pots of jam.")
	_supply("supply_dough", "Pizza Dough", "dough", 10, 6.0, "crate", false, 0, "10 balls of pizza dough.")
	_supply("supply_sauce", "Tomato Sauce", "sauce", 10, 5.0, "carton", false, 0, "10 jars of tomato sauce.")
	_supply("supply_cheese", "Cheese", "cheese", 10, 8.0, "crate_cold", true, 0, "10 portions of cheese. Keep cold.")
	_supply("supply_pepperoni", "Pepperoni", "pepperoni", 10, 7.0, "carton", false, 0, "10 portions of pepperoni.")
	_supply("supply_mushrooms", "Mushrooms", "mushroom", 8, 5.0, "crate", false, 0, "8 mushrooms.")
	_supply("supply_syrup", "Soda Syrup", "soda_syrup", 2, 10.0, "carton", false, 0, "2 syrup boxes (12 sodas each).")
	_supply("supply_kegs", "Beer Kegs", "keg", 2, 26.0, "crate", false, 0, "2 kegs (16 pints each).")
	_supply("supply_wings", "Chicken Wings", "wings", 10, 14.0, "crate_cold", true, 0, "10 portions of wings. Keep cold.")
	_supply("supply_dip", "Dip", "dip", 12, 4.0, "carton", false, 0, "12 pots of dip.")


func _recipe(id: String, name: String, cont: String, req: Array, opt: Array, price: float, weight: float, eat: float, plating: String, color: Color, steps: Array, day := 1, short := "") -> void:
	var r := RecipeDef.new()
	r.id = StringName(id)
	r.display_name = name
	r.short_name = short
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
		["Grill a patty until medium", "Put a bun on a plate", "Add the patty", "(Optional) add lettuce or tomato"], 1, "Burger")
	_recipe("fries", "Crispy Fries", "plate", ["fries"], [], 5.0, 1.0, 8.0, "fries", Pal.FRIES,
		["Cut a potato on the cutting board", "Fry until crispy", "Plate it"], 1, "Fries")
	_recipe("salad", "Garden Salad", "plate", ["lettuce_chopped", "tomato_sliced"], [], 8.0, 0.6, 9.0, "salad", Pal.LETTUCE,
		["Chop lettuce", "Slice a tomato", "Plate both"], 1, "Salad")
	_recipe("coffee", "Coffee", "mug", ["coffee"], [], 4.0, 1.0, 6.0, "drink", Pal.COFFEE,
		["Put a clean mug under the coffee machine", "Take it when it's just right"])
	_recipe("latte", "Latte", "mug", ["coffee", "milk"], [], 5.0, 0.9, 7.0, "drink", Color("e0c39a"),
		["Pour milk into a clean mug", "Put it under the coffee machine", "Take it when it's just right"])
	_recipe("croissant", "Croissant", "plate", ["croissant"], ["jam"], 4.0, 1.0, 6.0, "generic", Color("e0a050"),
		["Bake a croissant in the oven until golden", "Plate it", "(Optional) add jam"])
	_recipe("muffin", "Muffin", "plate", ["muffin"], [], 3.5, 0.8, 5.0, "generic", Color("b07440"),
		["Put a muffin on a plate"])
	_recipe("pizza", "Pizza", "plate", ["dough", "sauce", "cheese"], ["pepperoni", "mushroom_sliced"], 13.0, 1.4, 13.0, "generic", Color("e2604a"),
		["Put dough on a plate", "Add sauce and cheese", "(Optional) pepperoni or sliced mushrooms", "Bake the plate in the oven until golden"])
	_recipe("soda", "Soda", "mug", ["soda"], [], 3.0, 1.0, 5.0, "drink", Color("7a3a2a"),
		["Put a clean mug under the soda fountain", "Take it when it's full"])
	_recipe("beer", "Beer", "mug", ["beer"], [], 6.0, 1.2, 8.0, "drink", Color("e8b04a"),
		["Put a clean mug under the beer tap", "Take it when it's full (not foaming over)"])
	_recipe("wings", "Chicken Wings", "plate", ["wings"], ["dip"], 10.0, 1.3, 11.0, "generic", Color("d06a32"),
		["Fry wings until crispy", "Plate them", "(Optional) add dip"], 1, "Wings")


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
	_fixture("grill", "Flat-top Grill", A + "grill.tscn", "appliance", 140.0, "Cooks patties. Watch the colour — and the smoke.", {"flammable": true, "can_break": true, "powered": true})
	_fixture("fryer", "Deep Fryer", A + "fryer.tscn", "appliance", 160.0, "Turns cut potatoes into crispy fries. Grease fires happen.", {"flammable": true, "can_break": true, "powered": true})
	_fixture("coffee_machine", "Coffee Machine", A + "coffee_machine.tscn", "appliance", 120.0, "Brews into clean mugs automatically. Refill the bean hopper.", {"can_break": true, "powered": true})
	_fixture("oven", "Pizza Oven", A + "oven.tscn", "appliance", 180.0, "Bakes croissants, or a whole pizza on its plate. Watch the crust colour.", {"flammable": true, "can_break": true, "powered": true, "collision_height": 1.3})
	_fixture("soda_fountain", "Soda Fountain", A + "soda_fountain.tscn", "appliance", 110.0, "Pours soda into clean mugs. Load syrup boxes into it.", {"can_break": true, "powered": true})
	_fixture("beer_tap", "Beer Tap", A + "beer_tap.tscn", "appliance", 140.0, "Pours pints into clean mugs. Swap in a fresh keg when it runs dry.", {"can_break": true})
	_fixture("fridge", "Glass Fridge", A + "fridge.tscn", "storage", 150.0, "Keeps one crate cold. Beef and lettuce spoil without it.", {"can_break": true, "collision_height": 1.9, "powered": true})
	_fixture("sink", "Sink", A + "sink.tscn", "appliance", 70.0, "Drop dirty dishes in and hold USE to scrub.")
	_fixture("dishwasher", "Hood Dishwasher", A + "dishwasher.tscn", "appliance", 220.0, "Load up to 10 dishes and press USE. Sometimes breaks down.", {"can_break": true, "collision_height": 1.4, "powered": true})
	_fixture("trash_bin", "Trash Bin", A + "trash_bin.tscn", "service", 25.0, "Throw away food or scrape plates. Empty it when full.", {"collision_height": 0.75})
	_fixture("dumpster", "Dumpster", A + "dumpster.tscn", "service", 60.0, "Outdoor bin for trash bags, empty crates and spoiled stock.", {"allowed_outdoors": true, "collision_height": 1.1})
	_fixture("plate_rack", "Plate Rack", F + "plate_rack.tscn", "service", 45.0, "Holds clean plates. Comes with 4 plates.")
	_fixture("mug_rack", "Mug Rack", F + "mug_rack.tscn", "service", 35.0, "Holds clean mugs. Comes with 4 mugs.")
	_fixture("shelf", "Storage Shelf", F + "shelf.tscn", "storage", 35.0, "Holds one crate where everyone can see it.", {"collision_height": 0.78})
	_fixture("cold_shelf", "Steel Shelf", F + "cold_shelf.tscn", "storage", 45.0, "Wire shelving for walk-in coolers. Anything in a cold room stays fresh.", {"collision_height": 0.78})
	_fixture("table", "Dining Table", F + "table.tscn", "furniture", 50.0, "Push tables together to seat bigger groups.", {"collision_height": 0.72, "allowed_outdoors": true})
	_fixture("chair", "Diner Chair", F + "chair.tscn", "furniture", 20.0, "Face it toward a table to add a seat.", {"blocks_movement": false, "allowed_outdoors": true})
	_fixture("terminal", "Manager's Desk", F + "terminal.tscn", "service", 0.0, "Order supplies, equipment and staff.", {"purchasable": false})
	_fixture("menu_board", "Menu Board", F + "menu_board.tscn", "service", 40.0, "Cross ingredients off the menu when they run out.", {"collision_height": 1.7})
	_fixture("hydro_planter", "Hydroponic Planter", A + "hydro_planter.tscn", "appliance", 120.0, "Grows vegetables for free, slowly. USE to choose the crop, GRAB to harvest.", {"only_theme": "space", "powered": true, "collision_height": 1.0})
	_fixture("food_printer", "Food Printer", A + "food_printer.tscn", "appliance", 300.0, "Prints any ingredient, one portion at a time, for credits. USE to choose what it prints.", {"only_theme": "space", "powered": true, "can_break": true, "collision_height": 1.5})
	_fixture("market_stall", "Market Stall", F + "market_stall.tscn", "service", 0.0, "Sells crates on a station platform.", {"purchasable": false, "movable": false, "allowed_outdoors": true, "collision_height": 1.0})
	_fixture("open_sign", "Open Sign", F + "open_sign.tscn", "service", 0.0, "Hold USE to open the restaurant.", {"purchasable": false, "collision_height": 1.6})
	_fixture("register", "Cash Register", F + "register.tscn", "service", 80.0, "Ka-ching. Purely for the vibes (and a spare counter).")
	_fixture("plant_pot", "Potted Plant", F + "plant_pot.tscn", "decor", 25.0, "Makes the dining room a little nicer.", {"ambience": 0.02, "collision_height": 1.0, "allowed_outdoors": true})
	_fixture("jukebox", "Jukebox", F + "jukebox.tscn", "decor", 180.0, "Customers wait a bit more patiently.", {"ambience": 0.05, "collision_height": 1.2, "unlock_day": 2})
	_fixture("extinguisher_station", "Extinguisher Stand", F + "extinguisher_station.tscn", "service", 60.0, "Holds a fire extinguisher, which slowly refills here.", {"collision_height": 1.8})
	_fixture("mop_station", "Mop Bucket", F + "mop_station.tscn", "service", 30.0, "Home of the mop.", {"collision_height": 0.6})
	_fixture("conveyor", "Conveyor Belt", M + "conveyor.tscn", "automation", 70.0, "Moves items toward the fixture it faces. Chain them!", {"collision_height": 0.72, "unlock_day": 2, "powered": true})
	_fixture("grabber", "Grabber Arm", M + "grabber.tscn", "automation", 120.0, "Takes one item from behind and puts it in front. Pulls single ingredients out of crates.", {"collision_height": 0.66, "unlock_day": 2, "can_break": true, "powered": true})
	_fixture("auto_chopper", "Auto-Chopper", A + "auto_chopper.tscn", "automation", 260.0, "Slowly chops whatever is placed on it, no hands needed.", {"unlock_day": 3, "can_break": true, "powered": true})


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
		"recipe_weights": {"fries": 1.8, "burger": 1.3, "salad": 0.6}, "mess": 0.75, "tip": 0.9, "spawn_weight": 0.55,
		"hour_weights": {12: 1.2, 13: 1.0, 17: 1.4, 18: 1.6, 19: 1.2, -1: 0.45}, "description": "Big tables, lots of fries, lots of crumbs."})
	_arch("work_crew", "Work Crew", {"group_min": 2, "group_max": 4, "patience": 0.75, "dishes_min": 1, "dishes_max": 2, "drink_chance": 0.5,
		"recipe_weights": {"burger": 2.0, "fries": 1.6, "salad": 0.25}, "tip": 0.8, "mess": 0.3, "spawn_weight": 0.8,
		"hour_weights": {11: 1.0, 12: 2.3, 13: 1.7, -1: 0.25}, "accessory": &"hard_hat",
		"outfit_colors": PackedColorArray([Color("f28c28"), Color("4f6d8f"), Color("7a8f5a")]), "description": "Hungry and in a hurry. Lunchtime regulars."})
	_arch("business", "Business Lunch", {"group_min": 2, "group_max": 3, "patience": 0.95, "drink_chance": 0.9, "spend": 1.3, "tip": 1.4,
		"eat_speed": 0.8, "recipe_weights": {"salad": 1.6, "fries": 0.5}, "min_day": 2, "spawn_weight": 0.5,
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
	_arch("regular", "The Regular", {"group_min": 1, "group_max": 1, "patience": 1.3, "drink_chance": 1.0, "tip": 1.6,
		"recipe_weights": {"burger": 6.0, "fries": 0.3, "salad": 0.2}, "reputation_weight": 2.0,
		"min_day": 2, "spawn_weight": 0.35, "max_per_day": 1, "fixed_look_seed": 4242, "hour_weights": {11: 3.0, 12: 1.5, -1: 0.3},
		"accessory": &"bowtie", "description": "Comes in every day, always orders the burger and a coffee. Loyal — don't let them down."})
	_arch("commuter", "Commuter", {"group_min": 1, "group_max": 1, "patience": 0.65, "drink_chance": 0.95, "eat_speed": 1.5,
		"recipe_weights": {"coffee": 2.0, "croissant": 1.5, "latte": 1.2}, "spawn_weight": 0.9, "accessory": &"scarf",
		"hour_weights": {7: 2.5, 8: 2.6, 9: 1.5, 17: 1.5, -1: 0.4}, "mess": 0.05, "description": "On the way to work. Coffee, now."})
	_arch("student", "Students", {"group_min": 1, "group_max": 3, "patience": 1.15, "drink_chance": 0.6, "spend": 0.85, "tip": 0.6,
		"recipe_weights": {"latte": 1.6, "muffin": 1.6, "pizza": 1.6, "soda": 1.4, "fries": 1.3}, "mess": 0.35, "spawn_weight": 0.8,
		"accessory": &"glasses", "hour_weights": {10: 1.4, 14: 1.6, 15: 1.6, 16: 1.4, 20: 1.4, 21: 1.4, -1: 0.6},
		"description": "Small budgets, big tables, in no hurry."})
	_arch("sports_fans", "Sports Fans", {"group_min": 2, "group_max": 4, "patience": 0.9, "drink_chance": 0.95,
		"recipe_weights": {"beer": 2.5, "wings": 2.2, "pizza": 1.6, "fries": 1.3}, "mess": 0.6, "spawn_weight": 0.8, "accessory": &"jersey",
		"outfit_colors": PackedColorArray([Color("d9483b"), Color("3d7fd1")]), "hour_weights": {18: 1.6, 19: 2.4, 20: 2.4, 21: 1.6, -1: 0.4},
		"description": "Here for the big game. Wings, pints and noise."})
	_arch("night_owls", "Night Owls", {"group_min": 1, "group_max": 2, "patience": 1.2, "drink_chance": 1.0, "tip": 1.2,
		"recipe_weights": {"beer": 1.6, "fries": 1.4, "soda": 0.8}, "spawn_weight": 0.6, "accessory": &"bandana",
		"hour_weights": {21: 1.5, 22: 2.4, 23: 2.6, -1: 0.3}, "description": "Late-night regulars. Easygoing, good tippers."})
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
	_room("storage", "Storage", "concrete", Pal.CONCRETE, Pal.CONCRETE_DARK, Pal.PLASTER_SHADE, {"light_color": Color("ffe9c9"), "has_windows": false})
	_room("loading", "Loading Dock", "loading", Color("b8b4aa"), Color("a8a49a"), Pal.FACADE, {"outdoor": true})
	_room("cooler", "Walk-in Cooler", "cold_tile", Pal.COLD_TILE, Color("b7d3de"), Color("dfeef3"), {"cold": true, "light_color": Color("d9f0ff"), "has_windows": false})
	_room("patio", "Patio", "patio", Color("cdb79a"), Color("b9a283"), Pal.FACADE, {"outdoor": true, "customer_area": true})
	# The train
	_room("coach", "Passenger Coach", "carpet", Color("7a2e34"), Color("8e3c42"), Color("efe2c6"), {"light_color": Color("ffd9a8")})
	_room("dining_car", "Dining Car", "planks", Color("b07a4c"), Color("8e5e38"), Color("f1e4c8"), {"customer_area": true, "light_color": Color("ffd59a")})
	_room("galley", "Galley", "tile_checker", Color("e6e2d6"), Color("b9c2c4"), Color("eef0e8"), {"light_color": Color("fff1dc")})
	_room("baggage", "Baggage Car", "planks", Color("a88a62"), Color("8f7350"), Color("d8c4a0"), {"light_color": Color("ffe9c9"), "has_windows": false})
	_room("platform", "Station Platform", "none", Color("bdb7ab"), Color("a9a397"), Pal.FACADE, {"outdoor": true, "fenced": true})
	_room("gangway", "Gangway", "planks", Color("6b5a4a"), Color("5a4a3c"), Color("3a3a3c"), {"light_color": Color("ffd9a8"), "has_windows": false})
	# The space station
	_room("airlock", "Docking Airlock", "grate", Color("5d6675"), Color("3c434f"), Color("c9d0da"), {"light_color": Color("d9ecff"), "has_windows": false})
	_room("lounge", "Star Lounge", "carpet", Color("2e3a5c"), Color("3b4a72"), Color("dfe4ee"), {"customer_area": true, "light_color": Color("e8e4ff")})
	_room("space_galley", "Galley", "deck", Color("d7dce3"), Color("a9b2bf"), Color("eef1f5"), {"light_color": Color("f2f6ff")})
	_room("hydroponics", "Hydroponics Bay", "grate", Color("557a55"), Color("3f5a43"), Color("e3efe0"), {"light_color": Color("e9ffd9"), "has_windows": false})
	_room("cargo", "Cargo Hold", "deck", Color("9aa3ae"), Color("6f7883"), Color("c9cfd6"), {"light_color": Color("e6eeff"), "has_windows": false})


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
	_expansion("hydro_bay", "Hydroponics Bay II", "hydroponics", Rect2i(16, -4, 5, 4), 500.0,
		[Vector4i(18, -1, 18, 0)],
		[{"def": "hydro_planter", "cell": Vector2i(16, -4), "rot": 0}, {"def": "hydro_planter", "cell": Vector2i(17, -4), "rot": 0}, {"def": "hydro_planter", "cell": Vector2i(19, -4), "rot": 0}, {"def": "hydro_planter", "cell": Vector2i(20, -4), "rot": 0}],
		"A second grow bay with four more planters.")
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
	_event("health_inspection", "Health Inspection", "inspection", 0.15, 3, {}, "A health inspector is visiting the neighbourhood.")
	_event("power_outage", "Power Cut", "disaster", 0.15, 4, {}, "", "Powered machines stop for a while and the lights flicker.")


func _format(id: String, name: String, opts: Dictionary) -> void:
	var f := RestaurantFormatDef.new()
	f.id = StringName(id)
	f.display_name = name
	for k in opts:
		var v = opts[k]
		if k in ["menu", "archetypes", "stations", "supplies"]:
			var arr: Array[StringName] = []
			for x in v:
				arr.push_back(StringName(x))
			v = arr
		elif k == "pantry":
			var shelf: Array[Dictionary] = []
			for x in v:
				shelf.push_back(x)
			v = shelf
		f.set(k, v)
	_save(f, "%s/formats/%s.tres" % [R, id])


func _formats() -> void:
	_format("diner", "Diner", {
		"menu": ["burger", "fries", "salad", "coffee"], "open_hour": 11, "close_hour": 21, "base_groups": 8.0,
		"hourly_demand": {11: 0.6, 12: 2.0, 13: 1.7, 14: 0.8, 15: 0.6, 16: 0.7, 17: 1.2, 18: 2.0, 19: 1.8, 20: 0.8},
		"archetypes": ["regular_folks", "family", "work_crew", "business", "date", "tourists", "traveler", "regular", "critic"],
		"stations": ["grill", "grill", "counter", "fryer", "cutting_board", "cutting_board", "coffee_machine", "counter"],
		"pantry": [{"supply": "supply_potatoes", "units": 6}, {"supply": "supply_buns", "units": 8}, {"supply": "supply_tomatoes", "units": 4}],
		"supplies": ["supply_beef", "supply_buns", "supply_potatoes", "supply_lettuce", "supply_tomatoes", "supply_coffee"],
		"opening": {"supply_beef": 1, "supply_buns": 1, "supply_potatoes": 1, "supply_lettuce": 1, "supply_tomatoes": 1, "supply_coffee": 1},
		"accent": Color("d9483b"), "sign_text": "DINER", "default_name": "The Corner Diner", "tagline": "Burgers off the grill, crispy fries and bottomless coffee.",
		"description": "Classic table service. Grill patties to medium, fry potatoes, chop salad. Busy at lunch and dinner."})
	_format("coffee_shop", "Coffee Shop", {
		"menu": ["coffee", "latte", "croissant", "muffin"], "open_hour": 7, "close_hour": 15, "base_groups": 11.0,
		"hourly_demand": {7: 1.4, 8: 2.3, 9: 1.6, 10: 0.8, 11: 0.7, 12: 1.3, 13: 1.0, 14: 0.7},
		"archetypes": ["regular_folks", "commuter", "student", "business", "date", "tourists", "critic"],
		"stations": ["oven", "oven", "counter", "coffee_machine", "counter", "counter", "coffee_machine", "counter"],
		"pantry": [{"supply": "supply_croissants", "units": 6}, {"supply": "supply_muffins", "units": 6}, {"supply": "supply_jam", "units": 6}],
		"supplies": ["supply_coffee", "supply_milk", "supply_croissants", "supply_muffins", "supply_jam"],
		"opening": {"supply_coffee": 2, "supply_milk": 1, "supply_croissants": 1, "supply_muffins": 1},
		"extra_mugs": 4, "food_chance": 0.5, "drink_bonus": 0.45,
		"accent": Color("8a5a3c"), "sign_text": "CAFE", "default_name": "Bean There", "tagline": "Early mornings, lattes and warm croissants.",
		"description": "Lots of small, quick orders. Keep the coffee machines loaded, bake croissants golden, and watch the morning rush."})
	_format("pizza_parlor", "Pizza Parlor", {
		"menu": ["pizza", "salad", "soda"], "open_hour": 12, "close_hour": 22, "base_groups": 8.0,
		"hourly_demand": {12: 1.4, 13: 1.2, 14: 0.6, 15: 0.5, 16: 0.7, 17: 1.3, 18: 2.0, 19: 2.1, 20: 1.4, 21: 0.7},
		"archetypes": ["regular_folks", "family", "student", "work_crew", "date", "tourists", "sports_fans", "critic"],
		"stations": ["oven", "oven", "counter", "counter", "cutting_board", "cutting_board", "soda_fountain", "counter"],
		"pantry": [{"supply": "supply_dough", "units": 6}, {"supply": "supply_sauce", "units": 6}, {"supply": "supply_pepperoni", "units": 6}],
		"supplies": ["supply_dough", "supply_sauce", "supply_cheese", "supply_pepperoni", "supply_mushrooms", "supply_lettuce", "supply_tomatoes", "supply_syrup"],
		"opening": {"supply_dough": 1, "supply_sauce": 1, "supply_cheese": 1, "supply_pepperoni": 1, "supply_mushrooms": 1, "supply_lettuce": 1, "supply_tomatoes": 1, "supply_syrup": 1},
		"drink_bonus": 0.1,
		"accent": Color("e2604a"), "sign_text": "PIZZA", "default_name": "Slice of Life", "tagline": "Build it, bake it, serve it hot.",
		"description": "Assemble pizzas on the plate (dough, sauce, cheese, toppings) and bake the whole plate. Big family tables in the evening."})
	_format("bar", "Bar & Grill", {
		"menu": ["beer", "soda", "wings", "fries"], "open_hour": 16, "close_hour": 24, "base_groups": 9.0,
		"hourly_demand": {16: 0.6, 17: 1.0, 18: 1.4, 19: 2.0, 20: 2.0, 21: 1.6, 22: 1.4, 23: 0.9},
		"archetypes": ["regular_folks", "sports_fans", "night_owls", "work_crew", "date", "business", "critic"],
		"stations": ["fryer", "fryer", "counter", "counter", "cutting_board", "counter", "beer_tap", "soda_fountain"],
		"pantry": [{"supply": "supply_potatoes", "units": 6}, {"supply": "supply_dip", "units": 6}],
		"supplies": ["supply_kegs", "supply_syrup", "supply_wings", "supply_dip", "supply_potatoes"],
		"opening": {"supply_kegs": 1, "supply_syrup": 1, "supply_wings": 1, "supply_dip": 1, "supply_potatoes": 1},
		"extra_mugs": 4, "food_chance": 0.6, "drink_bonus": 0.5,
		"accent": Color("3f6d4e"), "sign_text": "BAR", "default_name": "The Tipsy Tap", "tagline": "Pints, wings and the big game.",
		"description": "Open late. Pour pints before they foam over, fry wings and fries, and keep the kegs coming."})


func _location(id: String, name: String, opts: Dictionary) -> void:
	var l := LocationDef.new()
	l.id = StringName(id)
	l.display_name = name
	for k in opts:
		var v = opts[k]
		if k == "expansions":
			var arr: Array[StringName] = []
			for x in v:
				arr.push_back(StringName(x))
			v = arr
		elif k == "stops":
			v = PackedStringArray(v)
		l.set(k, v)
	_save(l, "%s/locations/%s.tres" % [R, id])


func _locations() -> void:
	_location("main_street", "Main Street", {"layout_path": "res://data/layouts/main_street.json",
		"expansions": ["dining_annex", "dish_room", "walk_in_cooler", "patio"], "theme": "street", "supply_mode": "truck",
		"accent": Color("4f8f8a"), "tagline": "A small-town storefront with room to grow.",
		"description": "The classic. Order tomorrow's ingredients from the manager's desk; a truck delivers them every morning."})
	_location("express", "Dining Car Express", {"layout_path": "res://data/layouts/train.json",
		"expansions": [], "theme": "train", "supply_mode": "market",
		"stops": ["Central Depot", "Millbrook", "Cedar Falls", "Port Quinn", "Ashdown", "Harlow Junction", "Briar Hill", "Stonebridge", "Lark Valley"],
		"accent": Color("2f5d50"), "tagline": "A restaurant on rails. Shop at every stop.",
		"description": "No delivery truck: buy ingredients from market stalls on the platform at each stop, and get back aboard before the whistle. Every stop has different deals."})
	_location("orbital", "Orbital Galley", {"layout_path": "res://data/layouts/space.json",
		"expansions": ["hydro_bay"], "theme": "space", "supply_mode": "grow",
		"accent": Color("3d4f7a"), "tagline": "Feeding hungry travellers in orbit.",
		"description": "Nothing gets delivered up here: grow vegetables in hydroponic planters and print everything else on the food printer (it costs credits). Alien guests welcome."})
