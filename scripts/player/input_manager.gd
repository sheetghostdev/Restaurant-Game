extends Node
## Autoload "Inputs": per-device input for local co-op.
##
## Godot's InputMap merges every device into one set of actions, which doesn't
## work for several people on one machine. Instead each local player is bound
## to an input *device*: keyboard scheme A (WASD), keyboard scheme B (arrows)
## or a gamepad. Devices are polled directly and expose a uniform state.
##
## Device ids: 0 = keyboard A, 1 = keyboard B, 100+n = gamepad n.

signal device_join_requested(device: int)

const KB_A := 0
const KB_B := 1
const PAD_BASE := 100

## Keyboard bindings (physical keys, so they work on any layout).
var kb_bindings := {
	KB_A: {
		"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
		"grab": [KEY_SPACE], "use": [KEY_E, KEY_F], "alt": [KEY_Q], "sprint": [KEY_SHIFT],
	},
	KB_B: {
		"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
		"grab": [KEY_ENTER, KEY_KP_0], "use": [KEY_SHIFT, KEY_KP_1], "alt": [KEY_SLASH, KEY_KP_2], "sprint": [KEY_CTRL, KEY_KP_3],
	},
}

## When only one keyboard player exists, scheme A also accepts the arrow keys.
var solo_keyboard := true
var _claimed := {}            ## device -> player slot


func _ready() -> void:
	_setup_ui_actions()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _setup_ui_actions() -> void:
	var defs := {
		"pause": [KEY_ESCAPE, JOY_BUTTON_START],
		"debug_toggle": [KEY_F1],
		"overview_toggle": [KEY_TAB, JOY_BUTTON_BACK],
		"recipe_book": [KEY_R, JOY_BUTTON_RIGHT_STICK],
		"zoom_in": [KEY_EQUAL, KEY_KP_ADD],
		"zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
		"quick_save": [KEY_F5],
	}
	for action in defs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in defs[action]:
			var ev: InputEvent
			if action in ["pause", "overview_toggle", "recipe_book"] and code is int and code < 32:
				var jb := InputEventJoypadButton.new()
				jb.button_index = code
				jb.device = -1
				ev = jb
			else:
				var k := InputEventKey.new()
				k.physical_keycode = code
				ev = k
			InputMap.action_add_event(action, ev)
	# Menus: WASD moves the selection too (arrows and gamepads already do).
	for pair in [["ui_up", KEY_W], ["ui_down", KEY_S], ["ui_left", KEY_A], ["ui_right", KEY_D]]:
		var wk := InputEventKey.new()
		wk.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], wk)
	# Wheel zoom
	for pair in [["zoom_in", MOUSE_BUTTON_WHEEL_UP], ["zoom_out", MOUSE_BUTTON_WHEEL_DOWN]]:
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)


# -----------------------------------------------------------------------------
# Polling
# -----------------------------------------------------------------------------

func _key_down(keys: Array) -> bool:
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return true
	return false


func _kb_move(device: int) -> Vector2:
	var b: Dictionary = kb_bindings[device]
	var v := Vector2(
		float(_key_down(b["right"])) - float(_key_down(b["left"])),
		float(_key_down(b["down"])) - float(_key_down(b["up"])))
	if device == KB_A and solo_keyboard:
		var b2: Dictionary = kb_bindings[KB_B]
		v += Vector2(
			float(_key_down(b2["right"])) - float(_key_down(b2["left"])),
			float(_key_down(b2["down"])) - float(_key_down(b2["up"])))
	return v.limit_length(1.0)


## Returns the current raw state for a device.
func read(device: int) -> Dictionary:
	if device == KB_A or device == KB_B:
		var b: Dictionary = kb_bindings[device]
		var grab := _key_down(b["grab"])
		var use := _key_down(b["use"])
		var alt := _key_down(b["alt"])
		var sprint := _key_down(b["sprint"])
		return {"move": _kb_move(device), "grab": grab, "use": use, "alt": alt, "sprint": sprint}
	var pad := device - PAD_BASE
	var mv := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
	if mv.length() < 0.22:
		mv = Vector2.ZERO
	else:
		mv = mv.normalized() * inverse_lerp(0.22, 1.0, minf(mv.length(), 1.0))
	var dp := Vector2(
		float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT)),
		float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP)))
	if dp != Vector2.ZERO:
		mv = dp.normalized()
	return {
		"move": mv,
		"grab": Input.is_joy_button_pressed(pad, JOY_BUTTON_A),
		"use": Input.is_joy_button_pressed(pad, JOY_BUTTON_X) or Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.5,
		"alt": Input.is_joy_button_pressed(pad, JOY_BUTTON_Y),
		"sprint": Input.is_joy_button_pressed(pad, JOY_BUTTON_B) or Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > 0.5 or Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_SHOULDER),
	}


# -----------------------------------------------------------------------------
# Joining
# -----------------------------------------------------------------------------

func claim(device: int, slot: int) -> void:
	_claimed[device] = slot
	solo_keyboard = not (_claimed.has(KB_A) and _claimed.has(KB_B))


func release(device: int) -> void:
	_claimed.erase(device)
	solo_keyboard = not (_claimed.has(KB_A) and _claimed.has(KB_B))


func release_all() -> void:
	_claimed.clear()
	solo_keyboard = true


func is_claimed(device: int) -> bool:
	return _claimed.has(device)


func device_name(device: int) -> String:
	if device == KB_A:
		return "Keyboard (WASD)"
	if device == KB_B:
		return "Keyboard (Arrows)"
	return "Gamepad %d" % (device - PAD_BASE + 1)


func grab_hint(device: int) -> String:
	if device == KB_A:
		return "Space"
	if device == KB_B:
		return "Enter"
	return "A"


func use_hint(device: int) -> String:
	if device == KB_A:
		return "E"
	if device == KB_B:
		return "R-Shift"
	return "X"


func alt_hint(device: int) -> String:
	if device == KB_A:
		return "Q"
	if device == KB_B:
		return "/"
	return "Y"


## Detects a "join" press on any unclaimed device.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		var dev: int = PAD_BASE + event.device
		if not _claimed.has(dev):
			device_join_requested.emit(dev)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ENTER, KEY_KP_0] and not _claimed.has(KB_B) and _claimed.has(KB_A):
			device_join_requested.emit(KB_B)
		elif event.physical_keycode == KEY_SPACE and not _claimed.has(KB_A):
			device_join_requested.emit(KB_A)
