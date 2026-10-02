class_name Entity
extends Node3D
## Base class for every networked, saveable thing in the world (items,
## fixtures, customers, staff, messes, vehicles). Players implement the same
## interface on a CharacterBody3D.
##
## Authority model: gameplay state is only mutated on the authority (server or
## offline host). After changing replicated state call `mark_dirty()`; the
## Replicator ships `get_state()` to clients, which call `set_state()`.

var net_id := 0
var def_id: StringName = &""
var world: GameWorld


func get_kind() -> StringName:
	return &"entity"


## Full replicated / saved state, excluding identity and location.
func get_state() -> Dictionary:
	return {}


func set_state(_d: Dictionary) -> void:
	pass


## Where the entity lives (slot, floor position, grid cell...).
func get_location() -> Dictionary:
	return {"pos": [position.x, position.y, position.z], "yaw": rotation.y}


func set_location(d: Dictionary) -> void:
	if d.has("pos"):
		var p: Array = d["pos"]
		position = Vector3(p[0], p[1], p[2])
	if d.has("yaw"):
		rotation.y = d["yaw"]


func mark_dirty() -> void:
	if world and world.replicator:
		world.replicator.mark_dirty(self)


func is_authority() -> bool:
	return Net.is_authority()


## Called on the authority every physics frame by the world.
func server_tick(_delta: float) -> void:
	pass


func display_name() -> String:
	return String(def_id).capitalize()
