class_name Terminal
extends FixtureComponent
## The manager's desk: opens the supplier catalog (equipment, supplies, staff,
## upgrades) for the player who uses it.


func query(actor: Node, verb: int) -> Dictionary:
	if verb == GameConst.Verb.USE:
		return {"label": "Open catalog"}
	return {}


func perform(actor: Node, verb: int, _delta: float) -> bool:
	if verb != GameConst.Verb.USE:
		return false
	Net.open_catalog_for(actor)
	return true


func status_text() -> String:
	return "Order supplies & equipment"
