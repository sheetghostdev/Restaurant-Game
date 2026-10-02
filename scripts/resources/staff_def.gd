class_name StaffDef
extends Resource
## An NPC employee. Employees run simple, predictable routines: they handle
## repetitive work so players can handle chaos.

@export var id: StringName
@export var display_name := ""
@export var role: StringName = &"dishwasher"
@export var hire_cost := 60.0
@export var daily_wage := 35.0
@export var work_speed := 0.6                     ## Relative to a player.
@export var walk_speed := 2.2
@export var uniform := Color.WHITE
@export var unlock_day := 1
@export_multiline var description := ""
