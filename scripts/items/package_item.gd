class_name PackageItem
extends Item
## A boxed fixture from the supplier. Carry it to where it should go and place
## it (GRAB) during a calm phase to unpack it into a working fixture.

var fixture_id: StringName


func fixture_def() -> FixtureDef:
	return Content.fixture(fixture_id)


func display_name() -> String:
	var f := fixture_def()
	return "%s (boxed)" % (f.display_name if f else "Equipment")


func status_text() -> String:
	return "Place it to unpack"


func is_heavy() -> bool:
	return true


func get_state() -> Dictionary:
	var d := super.get_state()
	d["f"] = String(fixture_id)
	return d


func set_state(d: Dictionary) -> void:
	super.set_state(d)
	fixture_id = StringName(d.get("f", ""))
