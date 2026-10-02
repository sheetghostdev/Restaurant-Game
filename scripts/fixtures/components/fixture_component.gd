class_name FixtureComponent
extends Node
## Behaviour module attached as a direct child of a Fixture. Components get the
## first chance to handle interactions (in tree order) and tick on the server.

var fixture: Fixture


func _enter_tree() -> void:
	fixture = get_parent() as Fixture


## Return {"label": String, "hold": bool} if this component handles the verb.
func query(_actor: Node, _verb: int) -> Dictionary:
	return {}


func perform(_actor: Node, _verb: int, _delta: float) -> bool:
	return false


## While true the fixture can't be used for anything else (e.g. on fire).
func blocks_interaction() -> bool:
	return false


## While true the fixture's machinery doesn't run (broken, on fire, no power).
func blocks_function() -> bool:
	return false


func server_tick(_delta: float) -> void:
	pass


func get_state() -> Dictionary:
	return {}


func set_state(_d: Dictionary) -> void:
	pass


func on_placed() -> void:
	pass


func on_lifted() -> void:
	pass


## Short status line shown when targeting the fixture.
func status_text() -> String:
	return ""


func world() -> GameWorld:
	return fixture.world if fixture else null
