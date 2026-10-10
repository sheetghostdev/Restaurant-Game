class_name RoomTypeDef
extends Resource
## Visual and gameplay properties of a kind of room.

@export var id: StringName
@export var display_name := ""
@export_enum("tile_checker", "planks", "concrete", "cold_tile", "patio", "loading", "carpet", "deck", "grate", "none") var floor_style := "planks"
@export var floor_a := Color.WHITE
@export var floor_b := Color.WHITE
@export var wall_color := Color.WHITE
@export var outdoor := false                      ## No walls / roof; fence instead.
@export var cold := false                         ## Everything stored inside stays fresh.
@export var customer_area := false                ## Customers may walk and sit here.
@export var staff_only := false                   ## Back of house: guests never walk through it.
@export var has_windows := true                   ## Back walls get windows.
@export var fenced := false                       ## Outdoor area nobody may wander off (a station platform).
@export var light_color := Color(1, 0.9, 0.75)
@export_multiline var description := ""
