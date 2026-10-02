extends Node
## Dev tool: boots the game and dumps every visible triangle (world space) so
## coplanar overlapping surfaces (z-fighting) can be found offline.
## Each triangle: mesh index, 3 world-space vertices, 3 vertex colours.
## Run: godot --headless --path . res://tools/dev/zfight_scan.tscn -- --out=/tmp/tris.bin [--expanded]

var out_path := "user://tris.bin"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.start_offline(false)
	await get_tree().create_timer(1.5).timeout
	var w := GameWorld.current
	if "--expanded" in OS.get_cmdline_user_args():
		w.economy.earn(5000.0, "scan")
		for e in [&"patio", &"dining_annex", &"dish_room", &"walk_in_cooler"]:
			w.build.buy_expansion(e)
		await get_tree().create_timer(1.0).timeout
	var buf := PackedFloat32Array()
	var names := []
	_collect(get_tree().root, buf, names)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_32(names.size())
	f.store_32(buf.size())
	f.store_buffer(buf.to_byte_array())
	f.store_string(JSON.stringify(names))
	f.close()
	print("dumped %d triangles from %d meshes" % [buf.size() / 22, names.size()])
	get_tree().quit()


func _collect(n: Node, buf: PackedFloat32Array, names: Array) -> void:
	if n is Node3D and not (n as Node3D).is_visible_in_tree():
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var xf := mi.global_transform
		var idx := names.size()
		names.push_back(String(mi.get_path()))
		var m := mi.mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var count := ind.size() if ind.size() > 0 else v.size()
			for t in range(0, count - 2, 3):
				buf.push_back(float(idx))
				for k in 3:
					var p := xf * v[ind[t + k] if ind.size() > 0 else t + k]
					buf.push_back(p.x)
					buf.push_back(p.y)
					buf.push_back(p.z)
				for k in 3:
					var c := cols[ind[t + k] if ind.size() > 0 else t + k] if cols.size() > 0 else Color.WHITE
					buf.push_back(c.r)
					buf.push_back(c.g)
					buf.push_back(c.b)
					buf.push_back(c.a)
	for c in n.get_children():
		_collect(c, buf, names)
