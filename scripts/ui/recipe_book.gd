class_name RecipeBook
extends Control
## The optional recipe book (R / right stick, or from the pause menu): one card
## per dish on today's menu, showing each ingredient's journey as pictures,
## raw › station › ready, like PlateUp's recipe cards. It doesn't pause or
## block anyone: the kitchen keeps running behind it.

var hud: HUD
var _grid: GridContainer
var _built_for := ""

## Which machine handles each kind of heat, and which takes each refill.
const HEAT_STATION := {&"grill": &"grill", &"fryer": &"fryer", &"oven": &"oven", &"brew": &"coffee_machine", &"pour": &"soda_fountain"}
const REFILL_STATION := {&"coffee_beans": &"coffee_machine", &"soda_syrup": &"soda_fountain", &"keg": &"beer_tap"}
const VERB := {&"grill": "Grill", &"fryer": "Fry", &"oven": "Bake", &"brew": "Brew", &"pour": "Pour"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := UITheme.panel()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(UITheme.heading("Recipe Book", 32))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UITheme.label("R / right stick: close", 16, "regular", Pal.UI_INK_SOFT))
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	v.add_child(_grid)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_rebuild()
	visible = true
	Audio.play_ui(&"ui_confirm")


func close() -> void:
	visible = false
	Audio.play_ui(&"ui_back")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("recipe_book"):
		if hud and hud.world and not hud.pause_menu.visible:
			toggle()
			get_viewport().set_input_as_handled()
	elif visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# The menu can change during the day (menu board): keep the cards current.
	if visible and _key() != _built_for:
		_rebuild()


func _menu() -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	if hud == null or hud.world == null or hud.world.format == null:
		return out
	for r in Content.menu_for(hud.world.format, hud.world.day.day if hud.world.day else 1):
		if RecipeManager.menu.has(r.id):
			out.push_back(r)
	return out


func _key() -> String:
	var ids := []
	for r in _menu():
		ids.push_back(String(r.id))
	return ",".join(ids) + String(DishPlating.cup)


func _rebuild() -> void:
	_built_for = _key()
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var menu := _menu()
	_grid.columns = 3 if menu.size() == 3 or menu.size() > 4 else 2
	for r in menu:
		_grid.add_child(make_card(r))


# -----------------------------------------------------------------------------
# Cards (static so tests and other screens can use them)
# -----------------------------------------------------------------------------

static func make_card(r: RecipeDef) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.card(Color("fffaf0"), Pal.UI_INK_SOFT, 10, 2, false))
	p.custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_icon("recipe:%s" % r.id, 64))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UITheme.label(r.display_name, 22, "bold"))
	var vessel := "on a plate" if r.container == "plate" else "in a %s" % DishPlating.cup_word().to_lower()
	if r.required.has(&"beer") or r.required.has(&"soda"):
		vessel = "in a glass"
	hv.add_child(UITheme.label("%s · served %s" % [GameConst.money(r.price), vessel], 15, "regular", Pal.UI_INK_SOFT))
	head.add_child(hv)
	for row in recipe_rows(r):
		v.add_child(_row_ui(row))
	return p


static func _row_ui(row: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	var steps: Array = row["steps"]
	for i in steps.size():
		if i > 0:
			var arrow := UITheme.label("+" if steps[i].get("plus", false) else "›", 26, "bold", Pal.UI_INK_SOFT)
			arrow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			arrow.custom_minimum_size = Vector2(0, 44)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h.add_child(arrow)
		h.add_child(_chip(steps[i]))
	if row.get("extra", false):
		var tag := UITheme.label("extra, if they ask", 14, "regular", Pal.UI_ACCENT)
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tag.custom_minimum_size = Vector2(0, 44)
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(tag)
	return h


static func _chip(step: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.custom_minimum_size = Vector2(78, 0)
	if step.has("icon"):
		var c := CenterContainer.new()
		c.add_child(_icon(step["icon"], 50))
		v.add_child(c)
	var l := UITheme.label(step.get("text", ""), 13, "bold", Pal.UI_INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(78, 0)
	v.add_child(l)
	return v


static func _icon(key: String, size: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = IconRenderer.get_icon(key)
	return tr


# -----------------------------------------------------------------------------
# Working out the steps from the item data
# -----------------------------------------------------------------------------

## One row per ingredient: [{icon, text}, ...] from raw to ready, plus a
## final row where the dish is put together under a machine or in the oven.
static func recipe_rows(r: RecipeDef) -> Array:
	var rows := []
	if r.container == "mug":
		return _drink_rows(r)
	# Pizza-style: build the plate first, then bake the whole thing.
	var bake := {}
	for id in r.required:
		var d := Content.item(id)
		if d and d.cook_profile and d.cook_profile.heat == &"oven" and r.required.size() > 1:
			bake = {"id": id, "profile": d.cook_profile}
	var together := []
	for id in r.required + r.optional:
		var steps := ingredient_steps(id, not bake.is_empty())
		# When baking the whole plate, plain toppings share one "a + b + c" row.
		if not bake.is_empty() and steps.size() == 1 and id in r.required:
			if not together.is_empty():
				steps[0]["plus"] = true
			together.append_array(steps)
			continue
		rows.push_back({"steps": steps, "extra": id in r.optional})
	if not together.is_empty():
		rows.push_front({"steps": together})
	if not bake.is_empty():
		var prof: CookProfile = bake["profile"]
		rows.push_back({"steps": [
			{"icon": "model:plate", "text": "Build it on a plate"},
			{"icon": "station:oven", "text": "Bake: %s" % prof.stage_names[prof.perfect_stage]},
			{"icon": "recipe:%s" % r.id, "text": r.display_name}]})
	return rows


## How one ingredient gets ready: chopped from something, cooked, or
## straight from its box ("just plate it").
static func ingredient_steps(id: StringName, skip_cooking := false) -> Array:
	var d := Content.item(id)
	if d == null:
		return []
	var steps := []
	var src := chopped_from(id)
	if src != &"":
		steps.push_back({"icon": "item:%s" % src, "text": Content.display_name(src)})
		steps.push_back({"icon": "station:cutting_board", "text": "Chop"})
	var cooks := d.cook_profile != null and not skip_cooking
	steps.push_back({"icon": "item:%s" % id, "text": ("Raw " + d.display_name.to_lower()) if cooks and src == &"" else d.display_name})
	if cooks:
		var prof := d.cook_profile
		steps.push_back({"icon": "station:%s" % HEAT_STATION.get(prof.heat, &"grill"), "text": "%s: %s" % [VERB.get(prof.heat, "Cook"), prof.stage_names[prof.perfect_stage]]})
		steps.push_back({"icon": "cooked:%s" % id, "text": d.display_name})
	elif src == &"" and not skip_cooking:
		steps.push_back({"text": "No cooking: just plate it"})
	return steps


static func _drink_rows(r: RecipeDef) -> Array:
	var rows := []
	var cup := "model:%s" % ("glass" if r.required.has(&"beer") or r.required.has(&"soda") else "mug")
	var main := [{"icon": cup, "text": "Clean " + ("glass" if cup == "model:glass" else "mug")}]
	var station := &""
	var verb := "Pour"
	for id in r.required:
		var d := Content.item(id)
		if d == null:
			continue
		if d.made_from != &"":
			station = REFILL_STATION.get(d.made_from, &"coffee_machine")
			if d.cook_profile:
				verb = "%s: %s" % [VERB.get(d.cook_profile.heat, "Pour"), d.cook_profile.stage_names[d.cook_profile.perfect_stage]]
			rows.push_back({"steps": [
				{"icon": "item:%s" % d.made_from, "text": Content.display_name(d.made_from)},
				{"icon": "station:%s" % station, "text": "Keep it loaded"}]})
		else:
			main.push_back({"icon": "item:%s" % id, "text": "Add " + d.display_name.to_lower()})
	if station != &"":
		main.push_back({"icon": "station:%s" % station, "text": verb})
	main.push_back({"icon": "recipe:%s" % r.id, "text": r.display_name})
	rows.push_front({"steps": main})
	return rows


## The whole item `id` is chopped from (potato for fries), if any.
static func chopped_from(id: StringName) -> StringName:
	for d in Content.items.values():
		if d.chop_into == id:
			return d.id
	return &""
