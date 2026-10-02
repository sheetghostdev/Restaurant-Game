class_name SupplyDef
extends Resource
## A purchasable container of ingredients as it arrives from the supplier.

@export var id: StringName
@export var display_name := ""
@export var item_id: StringName                   ## What is inside.
@export var quantity := 10
@export var price := 10.0
@export_enum("crate", "crate_cold", "sack", "carton") var container := "crate"
@export var needs_cold := false
@export var default_order := 1                    ## Starting standing-order quantity.
@export_multiline var description := ""
