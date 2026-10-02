extends Node3D
## Dev tool: lays out every procedural model and saves a screenshot.
## Run: godot --path . res://tools/dev/model_gallery.tscn -- --shot=out.png

const KEYS := [
	&"bun", &"bun_bottom", &"bun_top", &"patty", &"lettuce_head", &"lettuce_chopped", &"tomato", &"tomato_sliced",
	&"potato", &"potato_cut", &"coffee_beans", &"coffee_fill", &"fry_boat", &"plate", &"plate_dirty", &"mug",
	&"crate", &"crate_cold", &"sack", &"carton", &"extinguisher", &"mop", &"flatpack", &"trash_bag",
	&"counter", &"cutting_board", &"grill", &"fryer", &"coffee_machine", &"fridge", &"sink", &"dishwasher",
	&"trash_bin", &"plate_rack", &"mug_rack", &"shelf", &"extinguisher_station", &"mop_station", &"conveyor", &"grabber",
	&"auto_chopper", &"pass_counter", &"table", &"chair", &"terminal", &"open_sign", &"register", &"plant_pot",
	&"jukebox", &"tree", &"bush", &"lamp_post", &"bench", &"hydrant", &"for_sale_sign", &"cone",
]

var shot_path := ""
var spacing := 1.4
var cols := 8

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("d9cdb8")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff2df")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	sun.light_color = Color("fff1dc")
	add_child(sun)
	var floor_b := MeshBuilder.new()
	floor_b.block(Vector3(cols * spacing * 0.5 - spacing * 0.5, -0.05, 3.5 * spacing), Vector3(cols * spacing + 2, 0.05, 9 * spacing), Pal.PLINTH_TOP)
	var fm := MeshInstance3D.new()
	fm.mesh = floor_b.commit(Models.mat_main())
	add_child(fm)
	for i in KEYS.size():
		var n := Models.instance(KEYS[i])
		n.position = Vector3((i % cols) * spacing, 0, (i / cols) * spacing)
		var small := i < 24
		if small:
			n.scale = Vector3.ONE * 2.2
		add_child(n)
	var cam := Camera3D.new()
	cam.fov = 38
	add_child(cam)
	var center := Vector3(cols * spacing * 0.5 - spacing * 0.5, 0, 3.5 * spacing)
	cam.position = center + Vector3(0, 13.5, 9.5)
	cam.look_at(center)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if shot_path != "":
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("saved ", shot_path)
	get_tree().quit()
