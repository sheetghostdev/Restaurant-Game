class_name PauseMenu
extends Control
## Pause / options overlay. Pauses the simulation only in offline games.

var hud: HUD
var _list: VBoxContainer
var _settings: VBoxContainer
var _help: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.07, 0.1, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := UITheme.panel()
	card.custom_minimum_size = Vector2(520, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var t := UITheme.heading("Paused", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	v.add_child(_list)
	_list.add_child(UITheme.button("Resume", close))
	_list.add_child(UITheme.button("Save game", func():
		Net.request("save")
		Events.notify("Game saved", &"info")))
	_list.add_child(UITheme.button("Settings & controls", _toggle_settings))
	_list.add_child(UITheme.button("Quit to title", func():
		close()
		get_tree().call_group(&"main", "return_to_menu")))
	_settings = SettingsPanel.make()
	_settings.visible = false
	v.add_child(_settings)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close()
		elif hud and not hud.catalog.visible:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	if not Net.is_online():
		get_tree().paused = true
	(_list.get_child(0) as Button).grab_focus.call_deferred()


func close() -> void:
	visible = false
	_settings.visible = false
	get_tree().paused = false


func _toggle_settings() -> void:
	_settings.visible = not _settings.visible
