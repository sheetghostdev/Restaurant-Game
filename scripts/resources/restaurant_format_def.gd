class_name RestaurantFormatDef
extends Resource
## A business format (diner, cafe, food truck...). Formats choose the menu,
## the service style and the demand curve.

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
@export var playable := true
@export_multiline var description := ""
