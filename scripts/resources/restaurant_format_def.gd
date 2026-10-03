class_name RestaurantFormatDef
extends Resource
## A kind of restaurant (diner, coffee shop, pizza parlor, bar), chosen when a
## new game starts. Formats choose the menu, opening hours, demand curve, the
## kitchen equipment you start with and what the supplier sells you.

@export var id: StringName
@export var display_name := ""
@export_enum("table", "counter", "buffet", "window") var service_style := "table"
@export var menu: Array[StringName] = []
@export var open_hour := 11
@export var close_hour := 21
@export var service_seconds := 420.0              ## Real seconds for a full service.
@export var base_groups := 9.0                    ## Customer groups on day 1 at 0 reputation.
@export var hourly_demand := {}                   ## hour -> relative demand
@export var archetypes: Array[StringName] = []
## Kitchen equipment for the location's station slots, in slot order
## ("counter" for a plain worktop).
@export var stations: Array[StringName] = []
@export var pantry: Array[Dictionary] = []        ## Opening stock on the pantry shelves, in shelf order: {"supply", "units"}.
@export var supplies: Array[StringName] = []      ## What the supplier sells (empty = everything).
@export var opening := {}                         ## supply id -> crates in the free day-one delivery.
@export var food_chance := 1.0                    ## Chance each adult orders food at all.
@export var drink_bonus := 0.0                    ## Added to every guest's chance of ordering a drink.
@export var accent := Color.WHITE                 ## Card colour on the new-game screen.
@export var tagline := ""
@export var default_name := ""                    ## Restaurant name when the player doesn't pick one.
@export var sign_text := "DINER"                  ## The big word on the street sign.                         ## One line for the new-game screen.
@export var playable := true
@export_multiline var description := ""
