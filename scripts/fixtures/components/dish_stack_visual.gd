class_name DishStackVisual
extends Node3D
## Shows a pile of plates and mugs from plain counts (sinks, dishwashers,
## racks). Rebuilt only when the counts change.

var _key := ""


func show_counts(plates: int, mugs: int, dirty: bool, spread := false) -> void:
	var key := "%d|%d|%s|%s" % [plates, mugs, dirty, spread]
	if key == _key:
		return
	_key = key
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var y := 0.0
	for k in plates:
		var p := Models.instance(&"plate_dirty" if dirty else &"plate")
		p.position = Vector3(0, y, 0)
		if spread:
			p.position = Vector3((k % 2) * 0.05 - 0.025, (k / 2) * 0.034, 0)
		p.rotation.y = k * 0.9
		add_child(p)
		y += 0.034
	for k in mugs:
		var m := Models.instance(&"mug_dirty" if dirty else &"mug")
		var col := k % 3
		var row := (k / 3) % 2
		var layer := k / 6
		m.position = Vector3(-0.2 + col * 0.14 + (0.3 if plates > 0 else 0.0), layer * 0.125, -0.08 + row * 0.16)
		m.rotation.y = k * 1.1
		add_child(m)
