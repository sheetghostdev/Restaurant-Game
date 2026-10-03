class_name LocationDef
extends Resource
## A place to run a restaurant: Main Street, a train, a space station.
## Locations provide the starting building, its surroundings and how
## ingredients reach the kitchen.

@export var id: StringName
@export var display_name := ""
@export_file("*.json") var layout_path := ""
@export var demand := 1.0
@export var expansions: Array[StringName] = []
@export_enum("street", "train", "space") var theme := "street"
## How ingredients arrive: a delivery truck you order from ("truck"), market
## stalls at train stops ("market") or growing and printing them ("grow").
@export_enum("truck", "market", "grow") var supply_mode := "truck"
@export var stops: PackedStringArray = []         ## Train stations, in order.
@export var accent := Color.WHITE                 ## Card colour on the new-game screen.
@export var tagline := ""
@export var playable := true
@export_multiline var description := ""
