class_name UpgradeDef
extends Resource
## One-off purchases that change rules or add capacity.

@export var id: StringName
@export var display_name := ""
@export var price := 100.0
@export var effect: StringName                    ## e.g. extra_plates, express_supplier, bigger_dock
@export var amount := 1.0
@export var repeatable := false
@export var unlock_day := 1
@export_multiline var description := ""
