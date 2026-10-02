extends Node
## Dev tool: compiles every GDScript in the project and reports failures.
## Run: godot --headless --path . res://tools/dev/check_all.tscn

func _ready() -> void:
	var failed := 0
	var files: Array[String] = []
	_collect("res://scripts", files)
	_collect("res://tools", files)
	_collect("res://tests", files)
	for f in files:
		var s = load(f)
		if s == null:
			printerr("FAILED: ", f)
			failed += 1
	print("Checked %d scripts, %d failed" % [files.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)


func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir():
			if not n.begins_with("."):
				_collect(dir.path_join(n), out)
		elif n.ends_with(".gd"):
			out.push_back(dir.path_join(n))
		n = d.get_next()
