class_name ItemDef
extends Resource
## A physical thing players can carry: ingredients, prepared food, dishware,
## containers, tools and packages.

@export var id: StringName
@export var display_name := ""
@export_enum("food", "dish", "crate", "tool", "package", "trash") var item_class := "food"
@export var model: StringName                     ## Models key.
@export var color := Color.WHITE                  ## Identity colour (labels, icons, alerts).
@export var tags: PackedStringArray = []          ## e.g. choppable, plateable, cold.
@export var heavy := false                        ## Two-handed: slows the carrier.
@export var blocks_when_dropped := false          ## Becomes an obstacle on the floor.
@export var unit_cost := 1.0                      ## Used for waste accounting.
@export_group("Preparation")
@export var chop_into: StringName                 ## Item produced on a cutting board.
@export var made_from: StringName                 ## Raw ingredient it comes from, when not chopped (menu board).
@export var chop_work := 2.0                      ## Seconds of chopping.
@export var cook_profile: CookProfile
@export var plate_layer := 0                      ## Stacking order when plated.
@export var grow_seconds := 0.0                   ## > 0: hydroponic planters can grow it (seconds per unit).
@export_group("Freshness")
@export var perishable := false
@export var spoil_seconds := 300.0                ## Time out of cold storage before spoiling.
@export_multiline var description := ""


func has_tag(t: String) -> bool:
	return tags.has(t)


func is_food() -> bool:
	return item_class == "food"
