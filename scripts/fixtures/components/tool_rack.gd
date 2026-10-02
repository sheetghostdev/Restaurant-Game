class_name ToolRack
extends FixtureComponent
## Stand for a hand tool (extinguisher, mop). Slowly refills extinguishers.

@export var refill_rate := 0.12


func server_tick(delta: float) -> void:
	var s := fixture.primary_slot()
	if s and s.item is ToolItem:
		var t := s.item as ToolItem
		if t.charge < 1.0:
			t.charge = minf(t.charge + delta * refill_rate, 1.0)
			if fmod(t.charge, 0.1) < delta * refill_rate:
				t.mark_dirty()


func status_text() -> String:
	var s := fixture.primary_slot()
	if s and s.item:
		return s.item.display_name()
	return "Empty — return the tool here"
