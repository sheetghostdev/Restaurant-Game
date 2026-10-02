class_name RoomTypeDef
extends Resource
## Visual and gameplay properties of a kind of room.

@export var id: StringName
@export var display_name := ""
@export_enum("tile_checker", "planks", "concrete", "cold_tile", "patio", "loading") var floor_style := "planks"
@export var floor_a := Color.WHITE
@export var floor_b := Color.WHITE
@export var wall_color := Color.WHITE
@export var outdoor := false                      ## No walls / roof; fence instead.
@export var cold := false                         ## Everything stored inside stays fresh.
@export var customer_area := false                ## Customers may walk and sit here.
@export var light_color := Color(1, 0.9, 0.75)
@export_multiline var description := ""
