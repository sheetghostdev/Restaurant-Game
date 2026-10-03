class_name RecipeDef
extends Resource
## A menu item. Plates are matched against recipes by their contents:
## required ⊆ contents ⊆ required ∪ optional.

@export var id: StringName
@export var display_name := ""
@export var short_name := ""                      ## Shown on order tickets; display_name if empty.
@export_enum("plate", "mug") var container := "plate"
@export var required: Array[StringName] = []
@export var optional: Array[StringName] = []
@export var price := 10.0
@export var extra_price := 1.0                    ## Added per optional extra a guest asks for.
@export var menu_weight := 1.0                    ## Base popularity.
@export var eat_time := 10.0                      ## Seconds a customer spends eating it.
@export var unlock_day := 1
@export var icon_color := Color.WHITE
@export_enum("burger", "fries", "salad", "drink", "generic") var plating := "generic"
@export var prep_steps: PackedStringArray = []
@export_multiline var description := ""


func ticket_name() -> String:
	return short_name if short_name != "" else display_name


## True if a dish with `contents` (item ids) satisfies this recipe.
func is_satisfied_by(contents: Array) -> bool:
	for r in required:
		if not contents.has(r):
			return false
	for c in contents:
		if not required.has(c) and not optional.has(c):
			return false
	return true


## True if `contents` could still become this recipe by adding more items.
func is_partial(contents: Array) -> bool:
	var counts := {}
	for c in contents:
		if not required.has(c) and not optional.has(c):
			return false
		counts[c] = counts.get(c, 0) + 1
		if counts[c] > 1:
			return false
	return true
