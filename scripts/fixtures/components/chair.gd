class_name Chair
extends FixtureComponent
## Marks a seat. The chair's front faces the table it belongs to.


func on_placed() -> void:
	if world() and world().customers:
		world().customers.mark_tables_dirty()


func on_lifted() -> void:
	if world() and world().customers:
		world().customers.mark_tables_dirty()


func status_text() -> String:
	return "Face it toward a table"
