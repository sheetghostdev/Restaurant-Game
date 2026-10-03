extends Node
## Headless test of every restaurant type: each starts with its own kitchen,
## pantry, supplier list, hours and menu, and its signature dishes can be
## made with the same interactions players use.
## Run: godot --headless --path . res://tests/format_test.tscn

var failures := 0
var checks := 0
var main: Node
var w: GameWorld
var p: PlayerCharacter
var _log: Array[String] = []


func _ready() -> void:
	Saves.active_slot = "format_test"
	Saves.delete()
	Engine.time_scale = 4.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for fid in [&"diner", &"coffee_shop", &"pizza_parlor", &"bar"]:
		await _start(fid)
		await t_common(fid)
		match fid:
			&"coffee_shop":
				await t_coffee_shop()
			&"pizza_parlor":
				await t_pizza_parlor()
			&"bar":
				await t_bar()
	print("")
	print("==== %d checks, %d failures ====" % [checks, failures])
	for l in _log:
		print(l)
	Saves.delete()
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures > 0 else 0)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)
		_log.push_back("FAIL: [%s] %s" % [w.format.id if w and w.format else "?", msg])


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func fixture(def_id: StringName, i := 0) -> Fixture:
	var arr := w.grid.fixtures_of(def_id)
	arr.sort_custom(func(a, b): return a.cell.x < b.cell.x or (a.cell.x == b.cell.x and a.cell.y < b.cell.y))
	return arr[i] if i < arr.size() else null


func approach(t: Node3D) -> void:
	var front := Vector3(0, 0, 1)
	if t is Fixture:
		front = (t as Fixture).front_vec()
	p.global_position = t.global_position + front * 0.85
	p.global_position.y = 0
	var to := t.global_position - p.global_position
	p.rotation.y = atan2(to.x, to.z)
	p.facing = Vector3(sin(p.rotation.y), 0, cos(p.rotation.y))


func grab(t: Node3D) -> bool:
	approach(t)
	return w.interaction._perform(t, p, GameConst.Verb.GRAB, 0.0)


func free_counter() -> Fixture:
	for f in w.grid.fixtures_of(&"counter"):
		if f.primary_slot() and f.primary_slot().item == null:
			return f
	return null


## Puts a fresh `id` on a free counter (hands stay as they are) and returns
## that counter.
func stage(id: StringName) -> Fixture:
	var c := free_counter()
	w.spawn_item(id, {}, {"slot": [c.net_id, 0]})
	return c


func held_id() -> String:
	return String(p.held().def_id) if p.held() else ""


func take_dish(rack_id: StringName) -> DishItem:
	grab(fixture(rack_id))
	return p.held() as DishItem


func _start(fid: StringName) -> void:
	print("[%s]" % fid)
	main.start_offline(false, {"format": String(fid)})
	await wait(0.6)
	w = GameWorld.current
	p = w.players()[0]


# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

func t_common(fid: StringName) -> void:
	var fmt := w.format
	check(fmt != null and fmt.id == fid, "started a %s" % fid)
	check(w.restaurant_name == fmt.default_name, "named %s" % w.restaurant_name)
	for def_id in fmt.stations:
		check(not w.grid.fixtures_of(def_id).is_empty(), "kitchen has a %s" % def_id)
	var shelf_ids := []
	for sh in w.grid.fixtures_of(&"shelf"):
		var it = sh.primary_slot().item
		if it is CrateItem:
			shelf_ids.push_back(Content.supply_for_item((it as CrateItem).content_id).id)
	for e in fmt.pantry:
		check(shelf_ids.has(StringName(e["supply"])), "pantry shelf holds %s" % e["supply"])
	check(absf(w.day.hour - (fmt.open_hour - 3.0)) < 0.2, "morning starts 3h before opening (%.2f)" % w.day.hour)
	# Every menu ingredient can be bought from this restaurant's supplier.
	var sold := []
	for s in Content.supplies_for(fmt):
		sold.push_back(s.item_id)
	for id in Content.menu_ingredients(fmt):
		check(sold.has(id), "supplier sells %s" % id)
	# Day one: the free opening stock arrives.
	var want := 0
	for k in fmt.opening:
		want += int(fmt.opening[k])
	await wait(13.0)
	var crates := 0
	for it in w.items_root.get_children():
		if it is CrateItem:
			crates += 1
	check(crates == want, "opening delivery brought %d crates (%d)" % [want, crates])
	# Guests only order from this menu, and both food and drinks come up.
	var got := {}
	for i in 300:
		var a: CustomerArchetype = Content.archetype(fmt.archetypes[i % fmt.archetypes.size()])
		for o in w.customers.choose_orders(a, false)["orders"]:
			got[o["recipe"]] = true
	var off_menu := got.keys().filter(func(r): return not fmt.menu.has(r))
	check(off_menu.is_empty(), "guests order only from the menu %s" % [off_menu])
	check(got.size() == fmt.menu.size(), "every dish gets ordered (%d of %d)" % [got.size(), fmt.menu.size()])
	w.debug_command("start_service", [])
	check(absf(w.day.hour - fmt.open_hour) < 0.1, "opens at %s" % GameConst.clock_text(fmt.open_hour))


func t_coffee_shop() -> void:
	# Latte: milk in a mug, then coffee from the machine.
	var mug := take_dish(&"mug_rack")
	var c := stage(&"milk")
	check(mug != null and mug.is_mug(), "took a mug")
	grab(c)
	check(mug.content_ids().has(&"milk"), "mug picked up the milk")
	var cm := fixture(&"coffee_machine")
	grab(cm)
	check(cm.primary_slot().item == mug, "milky mug under the coffee machine")
	await wait(4.5)
	grab(cm)
	check(p.held() == mug and mug.recipe() != null and mug.recipe().id == &"latte", "made a latte")
	check(mug.quality() >= 0.95, "latte is perfect (%.2f)" % mug.quality())
	grab(free_counter())
	# Croissant: bake until golden, then plate it.
	p.hold(w.spawn_item(&"croissant"))
	var oven := fixture(&"oven")
	grab(oven)
	check(oven.primary_slot().item != null and oven.primary_slot().item.def_id == &"croissant", "croissant in the oven")
	await wait(7.5)
	grab(oven)
	check(held_id() == "croissant", "took the croissant out")
	grab(fixture(&"plate_rack"))
	var plate := p.held() as DishItem
	check(plate != null and plate.recipe() != null and plate.recipe().id == &"croissant", "plated a croissant")
	check(plate != null and plate.quality() >= 0.95, "golden croissant (%.2f)" % (plate.quality() if plate else 0.0))
	grab(free_counter())


func t_pizza_parlor() -> void:
	# Dough onto a plate straight from the rack, then sauce, cheese, pepperoni.
	p.hold(w.spawn_item(&"dough"))
	grab(fixture(&"plate_rack"))
	var pizza := p.held() as DishItem
	check(pizza != null and pizza.content_ids().has(&"dough"), "dough on a plate")
	for id in [&"sauce", &"cheese", &"pepperoni"]:
		var c := stage(id)
		grab(c)
		check(pizza.content_ids().has(id), "added %s" % id)
	check(pizza.recipe() != null and pizza.recipe().id == &"pizza", "it's a pizza")
	check(pizza.matches("ovenable"), "a pizza plate goes in the oven")
	var oven := fixture(&"oven")
	grab(oven)
	check(oven.primary_slot().item == pizza, "pizza in the oven")
	var ck0 := float(pizza.content_on(&"oven").get("ck", 0.0))
	await wait(12.0)
	var ck1 := float(pizza.content_on(&"oven").get("ck", 0.0))
	check(ck1 > ck0 + 0.5, "the crust bakes (%.2f)" % ck1)
	grab(oven)
	check(p.held() == pizza, "took the pizza out")
	check(pizza.quality() >= 0.95, "golden pizza (%.2f)" % pizza.quality())
	var o := {"recipe": &"pizza", "extras": [&"pepperoni"]}
	check(RecipeManager.is_exact(o, pizza), "exactly a pepperoni pizza")
	grab(free_counter())
	# Leave a plate in too long and it burns.
	var burnt := w.spawn_item(&"dishware") as DishItem
	burnt.add_content(&"dough", 1.2)
	p.hold(burnt)
	grab(oven)
	await wait(4.0)
	check(burnt.quality() < 0.7, "forgotten pizza overcooks (%.2f)" % burnt.quality())
	grab(oven)
	grab(free_counter())
	# Soda from the fountain.
	var mug := take_dish(&"mug_rack")
	var sf := fixture(&"soda_fountain")
	grab(sf)
	await wait(3.0)
	grab(sf)
	check(p.held() == mug and mug.recipe() != null and mug.recipe().id == &"soda", "poured a soda")
	grab(free_counter())


func t_bar() -> void:
	var mug := take_dish(&"mug_rack")
	var tap := fixture(&"beer_tap")
	grab(tap)
	check(tap.primary_slot().item == mug, "mug under the beer tap")
	await wait(3.0)
	grab(tap)
	check(p.held() == mug and mug.recipe() != null and mug.recipe().id == &"beer", "poured a pint")
	check(mug.quality() >= 0.95, "full, not foamy (%.2f)" % mug.quality())
	grab(free_counter())
	# Wings in the fryer, onto a plate, with dip.
	p.hold(w.spawn_item(&"wings"))
	var fryer := fixture(&"fryer")
	grab(fryer)
	check(fryer.primary_slot().item != null, "wings in the fryer")
	await wait(10.0)
	var plate := take_dish(&"plate_rack")
	grab(fryer)
	check(plate.content_ids().has(&"wings"), "plate picked up the wings")
	var c := stage(&"dip")
	grab(c)
	check(plate.recipe() != null and plate.recipe().id == &"wings", "wings with dip")
	check(plate.quality() >= 0.95, "crispy wings (%.2f)" % plate.quality())
	check(RecipeManager.is_exact({"recipe": &"wings", "extras": [&"dip"]}, plate), "exactly wings + dip")
	grab(free_counter())
	# Closing time after midnight reads right.
	check(GameConst.clock_text(24.5) == "12:30am", "half past midnight reads 12:30am")
	# Running the keg dry shows on the tap.
	var cb := tap.get_component("CoffeeBrewer") as CoffeeBrewer
	cb.beans = 0
	check(cb.status_text().to_lower().contains("keg"), "empty tap asks for a keg (%s)" % cb.status_text())
	p.hold(w.spawn_item(&"keg"))
	grab(tap)
	check(cb.beans == cb.servings_per_bag, "loaded a keg")
