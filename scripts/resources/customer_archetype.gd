class_name CustomerArchetype
extends Resource
## A kind of customer group. Archetypes create varied operational demands:
## group size, patience, appetite, timing, spending and mess.

@export var id: StringName
@export var display_name := ""
@export var group_min := 1
@export var group_max := 2
@export var child_chance := 0.0                   ## Chance a member is a child (smaller, messier).
@export var patience := 1.0                       ## Multiplier on all waits.
@export var dishes_min := 1                       ## Food dishes per person.
@export var dishes_max := 1
@export var drink_chance := 0.3                   ## Chance each person also orders a drink.
@export var recipe_weights := {}                  ## recipe id -> weight multiplier.
@export var spend := 1.0
@export var tip := 1.0
@export var eat_speed := 1.0
@export var mess := 0.2                           ## Chance of leaving crumbs / spills.
@export var reputation_weight := 1.0              ## How strongly their opinion counts.
@export var strictness := 0.0                     ## Raises the quality bar (critics).
@export var walk_speed := 1.6
@export var spawn_weight := 1.0
@export var min_reputation := 0.0
@export var min_day := 1
@export var hour_weights := {}                    ## hour (int) -> weight multiplier.
@export var outfit_colors: PackedColorArray = []
@export var accessory: StringName                 ## hard_hat, tie, camera, beret, backpack, ...
@export var hat_color := Color.WHITE
@export var fixed_look_seed := 0                  ## >0: always looks the same (regulars).
@export var max_per_day := 0                      ## 0 = unlimited.
@export_multiline var description := ""


func weight_at_hour(hour: int) -> float:
	if hour_weights.is_empty():
		return 1.0
	return float(hour_weights.get(hour, hour_weights.get(-1, 0.3)))
