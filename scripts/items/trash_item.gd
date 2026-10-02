class_name TrashItem
extends Item
## A full trash bag. Take it out to the dumpster.


func is_heavy() -> bool:
	return true


func status_text() -> String:
	return "Take it to the dumpster"
