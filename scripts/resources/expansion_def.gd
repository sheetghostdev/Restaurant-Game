class_name ExpansionDef
extends Resource
## A purchasable building addition. Rooms are rectangles on the grid; `doors`
## lists the edges (pairs of cells) that become openings when built.

@export var id: StringName
@export var display_name := ""
@export var room_type: StringName = &"dining"
@export var rect := Rect2i(0, 0, 4, 4)
@export var price := 400.0
@export var doors: Array[Vector4i] = []           ## (ax, az, bx, bz)
@export var requires: StringName                  ## Another expansion that must exist first.
## Grows an existing room (by its layout id, e.g. "kitchen") over `rect`
## instead of adding a new one: no wall in between, one bigger room. Rooms
## that lie wholly inside `rect` are knocked through and become part of it.
@export var grows_room: StringName
@export var unlock_day := 1
@export var starter_fixtures: Array[Dictionary] = []  ## [{def, cell:Vector2i, rot}]
@export_multiline var description := ""
