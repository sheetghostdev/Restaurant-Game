class_name EventDef
extends Resource
## Operational disasters and customer events. Events are occasional by design:
## they should create stories, not constant punishment.

@export var id: StringName
@export var display_name := ""
@export_enum("disaster", "crowd", "delivery", "inspection") var kind := "disaster"
@export var weight := 1.0
@export var min_day := 1
@export var max_per_day := 1
@export var chance_per_day := 0.3
@export var during_service := true
@export var params := {}
@export var warning_text := ""
@export_multiline var description := ""
