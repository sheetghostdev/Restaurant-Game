extends Node
## Autoload "Settings": persistent user preferences (user://settings.cfg).

const PATH := "user://settings.cfg"

var _values := {
	"master_volume": 0.9,
	"music_volume": 0.6,
	"sfx_volume": 0.9,
	"fullscreen": false,
	"tilt_shift": true,
	"sharp_shadows": true,     ## 8192 shadow map (more video memory) instead of 4096
	"player_name": "Chef",
	"last_address": "127.0.0.1",
	"difficulty": 1,          ## Difficulty.RELAXED / NORMAL / HECTIC
}


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in _values:
			_values[k] = cf.get_value("settings", k, _values[k])
	_apply_all.call_deferred()


func get_value(key: String) -> Variant:
	return _values.get(key)


func set_value(key: String, v: Variant) -> void:
	_values[key] = v
	_apply(key)
	var cf := ConfigFile.new()
	for k in _values:
		cf.set_value("settings", k, _values[k])
	cf.save(PATH)


func _apply_all() -> void:
	for k in _values:
		_apply(k)


func _apply(key: String) -> void:
	match key:
		"master_volume": Audio.set_bus_volume("Master", _values[key])
		"music_volume": Audio.set_bus_volume("Music", _values[key])
		"sfx_volume":
			Audio.set_bus_volume("SFX", _values[key])
			Audio.set_bus_volume("UI", _values[key])
		"fullscreen":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _values[key] else DisplayServer.WINDOW_MODE_WINDOWED)
		"tilt_shift":
			var w := GameWorld.current
			if w and w.camera:
				w.camera.tilt_shift = _values[key]
		"player_name":
			Net.player_name = _values[key]
		"sharp_shadows":
			if DisplayServer.get_name() != "headless":
				RenderingServer.directional_shadow_atlas_set_size(8192 if _values[key] else 4096, true)
