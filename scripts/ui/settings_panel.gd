class_name SettingsPanel
extends VBoxContainer
## Volume sliders, difficulty, display toggles and a controls reference.


static func make() -> SettingsPanel:
	var p := SettingsPanel.new()
	p._build()
	return p


func _build() -> void:
	add_theme_constant_override("separation", 6)
	for pair in [["Master", "master_volume"], ["Music", "music_volume"], ["Effects", "sfx_volume"]]:
		var h := HBoxContainer.new()
		var l := UITheme.label(pair[0], 18, "bold")
		l.custom_minimum_size = Vector2(110, 0)
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Settings.get_value(pair[1])
		s.custom_minimum_size = Vector2(300, 24)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = pair[1]
		s.value_changed.connect(func(v): Settings.set_value(key, v))
		h.add_child(s)
		add_child(h)
	# Difficulty (the host's choice applies to everyone in an online game)
	var dh := HBoxContainer.new()
	var dl := UITheme.label("Difficulty", 18, "bold")
	dl.custom_minimum_size = Vector2(110, 0)
	dh.add_child(dl)
	var opt := OptionButton.new()
	for i in Difficulty.NAMES.size():
		opt.add_item(Difficulty.NAMES[i], i)
	opt.selected = Difficulty.level()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(opt)
	add_child(dh)
	var blurb := UITheme.label(Difficulty.BLURBS[Difficulty.level()], 15, "regular", Pal.UI_INK_SOFT)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(460, 0)
	add_child(blurb)
	opt.item_selected.connect(func(i: int):
		Settings.set_value("difficulty", i)
		blurb.text = Difficulty.BLURBS[i])
	var fs := CheckBox.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Settings.get_value("fullscreen")
	fs.toggled.connect(func(on): Settings.set_value("fullscreen", on))
	add_child(fs)
	var ts := CheckBox.new()
	ts.text = "Miniature tilt-shift blur"
	ts.button_pressed = Settings.get_value("tilt_shift")
	ts.toggled.connect(func(on): Settings.set_value("tilt_shift", on))
	add_child(ts)
	var help := UITheme.label(
		"Keyboard A: WASD move · Space grab/drop · E use/chop/wash · Q rotate/ping · Shift sprint\n" +
		"Keyboard B: Arrows · Enter grab · R-Shift use · / rotate · R-Ctrl sprint\n" +
		"Gamepad: Stick · A grab · X use · Y rotate/ping · B/LT sprint · Start pause\n" +
		"Before opening and in the evening: GRAB empty furniture to pick it up (hold GRAB to move it with things on it).\n" +
		"R / right stick: recipe book. Tab: overview. +/-: zoom. F1: debug.", 15, "regular", Pal.UI_INK_SOFT)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(460, 0)
	add_child(help)
