class_name FixtureDef
extends Resource
## Anything placed on the restaurant grid: appliances, furniture, storage,
## automation and decor.

@export var id: StringName
@export var display_name := ""
@export var scene: PackedScene
@export_enum("appliance", "furniture", "storage", "automation", "decor", "service") var category := "appliance"
@export var price := 50.0
@export var purchasable := true
@export var unlock_day := 1
@export var unlock_reputation := 0.0
@export var model: StringName                     ## Catalog / preview model.
@export var flammable := false
@export var can_break := false
@export var powered := false                      ## Stops during a power cut.
@export var blocks_movement := true
@export var collision_height := 0.8
@export var allowed_outdoors := false
@export var ambience := 0.0                       ## Decor bonus to customer mood.
@export_multiline var description := ""
