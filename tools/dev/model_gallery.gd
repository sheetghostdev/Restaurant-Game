extends Node3D
## Dev tool: lays out models in a grid under game-like lighting and saves a
## screenshot, to check that each one reads clearly.
## Run: godot --path . res://tools/dev/model_gallery.tscn -- --keys=a,b,c --shot=out.png [--cols=4] [--scale=1]

func _ready() -> void:
	var keys: PackedStringArray = []
	var shot := "user://gallery.png"
	var cols := 4
	var scl := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--keys="):
			keys = a.substr(7).split(",", false)
		elif a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--scale="):
			scl = float(a.substr(8))
	var light := LightingRig.new()
	add_child(light)
	light.set_hour(13.0, true)
	var floor_b := MeshBuilder.new()
	var rows := int(ceil(float(keys.size()) / cols))
	var sp := 2.1
	floor_b.block(Vector3((cols - 1) * sp * 0.5, -0.05, (rows - 1) * sp * 0.5), Vector3(cols * sp + 1, 0.05, rows * sp + 1), Color("d9cbb2"))
	var fm := MeshInstance3D.new()
	fm.mesh = floor_b.commit(Models.mat_main())
	add_child(fm)
	for i in keys.size():
		var m := Models.instance(StringName(keys[i]))
		m.position = Vector3((i % cols) * sp, 0, (i / cols) * sp)
		m.scale = Vector3.ONE * scl
		add_child(m)
		var l := Label3D.new()
		l.text = keys[i]
		l.font_size = 40
		l.pixel_size = 0.004
		l.position = m.position + Vector3(0, 0.02, 0.75)
		l.rotation_degrees = Vector3(-90, 0, 0)
		l.modulate = Color.BLACK
		add_child(l)
	var cam := Camera3D.new()
	cam.fov = 34
	add_child(cam)
	var center := Vector3((cols - 1) * sp * 0.5, 0, (rows - 1) * sp * 0.5)
	var dist := maxf(cols, rows * 1.6) * sp * 1.15 + 1.0
	cam.position = center + Vector3(0, sin(deg_to_rad(54)), cos(deg_to_rad(54))) * dist
	cam.look_at(center, Vector3.UP)
	cam.current = true
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot)
	print("saved ", shot)
	get_tree().quit()
