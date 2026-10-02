class_name MainMenu
extends Node
## Title screen over a slowly turning miniature of the starting restaurant.

var main: Node
var _backdrop: Node3D
var _cam: Camera3D
var _angle := 0.0
var _status: Label
var _buttons: VBoxContainer
var _join_box: HBoxContainer
var _addr: LineEdit
var _name: LineEdit
var _settings: SettingsPanel
var _center := Vector3(11, 0, 4)
var _confirm_new := false


func _ready() -> void:
	_build_backdrop()
	_build_ui()


func _build_backdrop() -> void:
	_backdrop = Node3D.new()
	add_child(_backdrop)
	var light := LightingRig.new()
	_backdrop.add_child(light)
	light.set_hour(15.5, true)
	var loc: LocationDef = Content.locations.get(&"main_street")
	if loc == null:
		return
	var f := FileAccess.open(loc.layout_path, FileAccess.READ)
	if f == null:
		return
	var layout: Dictionary = JSON.parse_string(f.get_as_text())
	var grid := RestaurantGrid.new()
	_backdrop.add_child(grid)
	grid.load_layout(layout)
	var builder := RestaurantBuilder.new()
	_backdrop.add_child(builder)
	builder.setup(grid, layout)
	builder.rebuild()
	light.builder = builder
	for fx in layout.get("fixtures", []):
		var fd := Content.fixture(StringName(fx["def"]))
		if fd == null:
			continue
		var m := Models.instance(fd.model if fd.model != &"" else fd.id)
		var c: Array = fx["cell"]
		m.position = GameConst.cell_center(Vector2i(c[0], c[1]))
		m.rotation.y = int(fx.get("rot", 0)) * PI * 0.5
		_backdrop.add_child(m)
	var b := grid.building_bounds()
	_center = Vector3(b.get_center().x, 0, b.get_center().y)
	# A few diners to bring it to life
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var rig := CharacterRig.new()
		_backdrop.add_child(rig)
		var app := CharacterRig.random_appearance(rng)
		if i < 2:
			app = PlayerCharacter.appearance_for(i)
		rig.build(app)
		rig.position = Vector3(rng.randf_range(b.position.x + 1, b.end.x - 1), 0, rng.randf_range(b.position.y + 1, b.end.y - 1))
		rig.rotation.y = rng.randf() * TAU
		rig.anim = CharacterRig.Anim.IDLE
	_cam = Camera3D.new()
	_cam.fov = 32
	_backdrop.add_child(_cam)
	_cam.current = true
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 34.0
	attrs.dof_blur_far_transition = 12.0
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = 14.0
	attrs.dof_blur_near_transition = 6.0
	attrs.dof_blur_amount = 0.06
	_cam.attributes = attrs


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.anchor_bottom = 1.0
	shade.offset_right = 620
	shade.color = Color(0.1, 0.08, 0.07, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var v := VBoxContainer.new()
	v.position = Vector2(70, 70)
	v.custom_minimum_size = Vector2(480, 0)
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	var title := UITheme.heading("MISE EN\nCHAOS", 92, Pal.UI_PAPER)
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_outline_color", Pal.UI_INK)
	title.add_theme_constant_override("line_spacing", -18)
	v.add_child(title)
	var sub := UITheme.label("Build it. Stock it. Somehow keep it running.", 22, "bold", Pal.UI_PAPER)
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Pal.UI_INK)
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	v.add_child(gap)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	v.add_child(_buttons)
	_join_box = HBoxContainer.new()
	_join_box.visible = false
	_addr = LineEdit.new()
	_addr.text = Settings.get_value("last_address")
	_addr.custom_minimum_size = Vector2(260, 0)
	_join_box.add_child(_addr)
	_join_box.add_child(UITheme.button("Connect", func():
		Settings.set_value("last_address", _addr.text)
		main.start_join(_addr.text)))
	v.add_child(_join_box)
	var name_row := HBoxContainer.new()
	name_row.add_child(UITheme.label("Your name ", 18, "bold", Pal.UI_PAPER))
	_name = LineEdit.new()
	_name.text = Settings.get_value("player_name")
	_name.custom_minimum_size = Vector2(220, 0)
	_name.text_changed.connect(func(t): Settings.set_value("player_name", t.substr(0, 16)))
	name_row.add_child(_name)
	v.add_child(name_row)
	_status = UITheme.label("", 18, "bold", Pal.MUSTARD)
	_status.add_theme_constant_override("outline_size", 6)
	_status.add_theme_color_override("font_outline_color", Pal.UI_INK)
	v.add_child(_status)
	var settings_card := UITheme.panel()
	settings_card.visible = false
	_settings = SettingsPanel.make()
	settings_card.add_child(_settings)
	settings_card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	settings_card.position = Vector2(-560, -220)
	root.add_child(settings_card)
	_settings.set_meta(&"card", settings_card)
	var foot := UITheme.label("v%s · Godot %s · F1 in game for debug tools" % [ProjectSettings.get_setting("application/config/version"), Engine.get_version_info()["string"]], 14, "regular", Color(1, 1, 1, 0.75))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(20, -34)
	root.add_child(foot)


func refresh() -> void:
	for c in _buttons.get_children():
		c.queue_free()
	_confirm_new = false
	var has_save: bool = Saves.has_save()
	if has_save:
		var m := Saves.meta()
		_buttons.add_child(UITheme.button("Continue — Day %d (%s)" % [int(m.get("day", 1)), GameConst.money(m.get("money", 0.0))], func(): main.start_offline(true), 24))
	var new_btn := UITheme.button("New Restaurant", func(): _new_game(), 24)
	_buttons.add_child(new_btn)
	_buttons.add_child(UITheme.button("Host Online Game", func(): main.start_host(), 22))
	_buttons.add_child(UITheme.button("Join Online Game", func():
		_join_box.visible = not _join_box.visible
		if _join_box.visible:
			_addr.grab_focus(), 22))
	_buttons.add_child(UITheme.button("Settings", func():
		var card: Control = _settings.get_meta(&"card")
		card.visible = not card.visible, 22))
	_buttons.add_child(UITheme.button("Quit", func(): get_tree().quit(), 22))
	(_buttons.get_child(0) as Button).grab_focus.call_deferred()


func _new_game() -> void:
	if Saves.has_save() and not _confirm_new:
		_confirm_new = true
		set_status("This replaces your current restaurant. Press again to confirm.")
		return
	Saves.delete()
	main.start_offline(false)


func set_status(text: String) -> void:
	if _status:
		_status.text = text


func _process(delta: float) -> void:
	if _cam == null:
		return
	_angle += delta * 0.05
	var r := 27.0
	_cam.position = _center + Vector3(sin(_angle) * r, 17.0, cos(_angle) * r)
	_cam.look_at(_center + Vector3(-3.5, 0, 0).rotated(Vector3.UP, _angle), Vector3.UP)
