class_name LocationDef
extends Resource
## A place to open a restaurant. Locations provide the starting building and
## shape demand.

@export var id: StringName
@export var display_name := ""
@export_file("*.json") var layout_path := ""
@export var demand := 1.0
@export var expansions: Array[StringName] = []
@export var playable := true
@export_multiline var description := ""
