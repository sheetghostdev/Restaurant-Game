extends Node
## Autoload "Content": indexes every data resource under res://resources.
##
## Drop a new .tres (ItemDef, RecipeDef, FixtureDef, ...) anywhere under
## res://resources and it becomes available by id — no code changes needed.

const ROOT := "res://resources"

var items := {}
var supplies := {}
var recipes := {}
var fixtures := {}
var archetypes := {}
var expansions := {}
var room_types := {}
var staff := {}
var upgrades := {}
var events := {}
var formats := {}
var locations := {}

var _loaded := false


func _ready() -> void:
	load_all()


func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	_scan(ROOT)


func _scan(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		push_warning("Content: cannot open %s" % dir_path)
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var path := dir_path.path_join(n)
		if d.current_is_dir():
			if not n.begins_with("."):
				_scan(path)
		else:
			# Exported builds list remapped/converted resources with suffixes.
			if n.ends_with(".remap"):
				path = path.trim_suffix(".remap")
			if path.ends_with(".tres") or path.ends_with(".res"):
				_register(load(path))
		n = d.get_next()


func _register(r: Resource) -> void:
	if r == null:
		return
	if r is ItemDef:
		items[r.id] = r
	elif r is SupplyDef:
		supplies[r.id] = r
	elif r is RecipeDef:
		recipes[r.id] = r
	elif r is FixtureDef:
		fixtures[r.id] = r
	elif r is CustomerArchetype:
		archetypes[r.id] = r
	elif r is ExpansionDef:
		expansions[r.id] = r
	elif r is RoomTypeDef:
		room_types[r.id] = r
	elif r is StaffDef:
		staff[r.id] = r
	elif r is UpgradeDef:
		upgrades[r.id] = r
	elif r is EventDef:
		events[r.id] = r
	elif r is RestaurantFormatDef:
		formats[r.id] = r
	elif r is LocationDef:
		locations[r.id] = r


func item(id: StringName) -> ItemDef:
	return items.get(id)


func recipe(id: StringName) -> RecipeDef:
	return recipes.get(id)


func fixture(id: StringName) -> FixtureDef:
	return fixtures.get(id)


func supply(id: StringName) -> SupplyDef:
	return supplies.get(id)


func supply_for_item(item_id: StringName) -> SupplyDef:
	for s in supplies.values():
		if s.item_id == item_id:
			return s
	return null


func room_type(id: StringName) -> RoomTypeDef:
	return room_types.get(id)


func archetype(id: StringName) -> CustomerArchetype:
	return archetypes.get(id)


func display_name(id: StringName) -> String:
	for table in [items, recipes, fixtures, supplies]:
		if table.has(id):
			return table[id].display_name
	return String(id).capitalize()


## The raw ingredient a component comes from (sliced tomato -> tomato,
## fries -> potato, coffee -> beans). What the menu board strikes off.
func base_ingredient(id: StringName) -> StringName:
	var d := item(id)
	if d and d.made_from != &"":
		return d.made_from
	for other in items.values():
		if (other as ItemDef).chop_into == id:
			return other.id
	return id


## Raw ingredients used by a format's menu, in menu order (menu board rows).
func menu_ingredients(format: RestaurantFormatDef) -> Array[StringName]:
	var out: Array[StringName] = []
	for rid in format.menu:
		var r := recipe(rid)
		if r == null:
			continue
		for c in r.required + r.optional:
			var b := base_ingredient(c)
			if not out.has(b):
				out.push_back(b)
	return out


## Recipes on the menu of a format, sorted by price.
func menu_for(format: RestaurantFormatDef, day: int) -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	for id in format.menu:
		var r: RecipeDef = recipes.get(id)
		if r and r.unlock_day <= day:
			out.push_back(r)
	out.sort_custom(func(a, b): return a.price < b.price)
	return out


func sorted_values(table: Dictionary) -> Array:
	var arr := table.values()
	arr.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return arr
