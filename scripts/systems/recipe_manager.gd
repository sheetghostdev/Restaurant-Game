class_name RecipeManager
## Recipe matching and food-combination rules. Stateless: everything is derived
## from RecipeDef resources, so adding a recipe never requires code changes.

## Active menu ids for the running restaurant (set by the world on load).
static var menu: Array[StringName] = []


static func active_recipes() -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	if menu.is_empty():
		for r in Content.recipes.values():
			out.push_back(r)
	else:
		for id in menu:
			var r: RecipeDef = Content.recipe(id)
			if r:
				out.push_back(r)
	return out


static func container_of(dish: DishItem) -> String:
	return "mug" if dish.mugs > 0 else "plate"


## Could `id` go into `dish` and still be on the way to some recipe? Like
## can_add_food, but for things poured by a machine (no "plateable" tag).
static func can_extend(dish: DishItem, id: StringName) -> bool:
	if dish.dirty or dish.count() != 1:
		return false
	var ids := dish.content_ids()
	ids.push_back(id)
	var cont := container_of(dish)
	for r in active_recipes():
		if r.container == cont and r.is_partial(ids):
			return true
	return false


## Could `food_id` start a dish in an empty `container` ("plate" / "mug")?
static func can_start(container: String, food_id: StringName) -> bool:
	var item_def := Content.item(food_id)
	if item_def == null or not item_def.has_tag("plateable"):
		return false
	for r in active_recipes():
		if r.container == container and r.is_partial([food_id]):
			return true
	return false


## Could `food` be added to `dish` and still be on the way to some recipe?
static func can_add_food(dish: DishItem, food_id: StringName) -> bool:
	if dish.dirty or dish.count() != 1:
		return false
	var item_def := Content.item(food_id)
	if item_def == null or not item_def.has_tag("plateable"):
		return false
	var ids := dish.content_ids()
	ids.push_back(food_id)
	var cont := container_of(dish)
	for r in active_recipes():
		if r.container == cont and r.is_partial(ids):
			return true
	return false


## Best complete recipe for the dish contents (most required components wins).
static func match_dish(dish: DishItem) -> RecipeDef:
	if dish.dirty or dish.contents.is_empty():
		return null
	return match_contents(dish.content_ids(), container_of(dish))


static func match_contents(ids: Array, cont: String) -> RecipeDef:
	var best: RecipeDef = null
	for r in active_recipes():
		if r.container != cont:
			continue
		if r.is_satisfied_by(ids):
			if best == null or r.required.size() > best.required.size():
				best = r
	return best


## Overall quality 0..1 of a dish (worst component dominates).
static func dish_quality(dish: DishItem) -> float:
	var q := 1.0
	for c in dish.contents:
		if c.get("sd", false):
			return 0.0
		var d := Content.item(c["id"])
		if d and d.cook_profile:
			q = minf(q, d.cook_profile.quality(c.get("ck", 0.0)))
	return q


## Worst component's stage name (for feedback like "Burnt!").
static func worst_stage(dish: DishItem) -> String:
	var worst_q := 2.0
	var worst := ""
	for c in dish.contents:
		if c.get("sd", false):
			return "Spoiled"
		var d := Content.item(c["id"])
		if d and d.cook_profile:
			var q := d.cook_profile.quality(c.get("ck", 0.0))
			if q < worst_q:
				worst_q = q
				worst = d.cook_profile.stage_name(c.get("ck", 0.0))
	return worst


static func satisfies(order_recipe: RecipeDef, dish: DishItem) -> bool:
	if dish.dirty or dish.count() != 1:
		return false
	if order_recipe.container != container_of(dish):
		return false
	return order_recipe.is_satisfied_by(dish.content_ids())


static func quality_word(q: float) -> String:
	if q >= 0.95:
		return "Perfect"
	if q >= 0.7:
		return "Good"
	if q >= 0.4:
		return "Okay"
	if q > 0.0:
		return "Poor"
	return "Ruined"


# -----------------------------------------------------------------------------
# Orders: a recipe plus the optional extras one guest asked for
# -----------------------------------------------------------------------------

## "burger+tomato_sliced": recipe id, then each extra. Used in thought bubbles,
## tickets and icon keys.
static func order_code(order: Dictionary) -> String:
	var parts := [String(order["recipe"])]
	for e in order.get("extras", []):
		parts.push_back(String(e))
	return "+".join(parts)


static func parse_code(code: String) -> Dictionary:
	var parts := code.split("+", false)
	var extras: Array[StringName] = []
	for i in range(1, parts.size()):
		extras.push_back(StringName(parts[i]))
	return {"recipe": StringName(parts[0]) if parts.size() > 0 else &"", "extras": extras}


## Optional extras the guest wanted but the dish lacks, and extras on the dish
## they didn't ask for: {"missing": [...], "unwanted": [...]}.
static func extras_diff(order: Dictionary, dish: DishItem) -> Dictionary:
	var r := Content.recipe(order["recipe"])
	var ids := dish.content_ids()
	var wanted: Array = order.get("extras", [])
	var missing := []
	var unwanted := []
	if r:
		for opt in r.optional:
			var want := wanted.has(opt)
			var has := ids.has(opt)
			if want and not has:
				missing.push_back(opt)
			elif has and not want:
				unwanted.push_back(opt)
	return {"missing": missing, "unwanted": unwanted}


static func is_exact(order: Dictionary, dish: DishItem) -> bool:
	var d := extras_diff(order, dish)
	return d["missing"].is_empty() and d["unwanted"].is_empty()


static func order_price(order: Dictionary) -> float:
	var r := Content.recipe(order["recipe"])
	if r == null:
		return 0.0
	return r.price + r.extra_price * order.get("extras", []).size()
