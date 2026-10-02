extends Node
## Autoload "Audio": pooled positional sound effects, state-driven loops and
## layered adaptive music.
##
## Sounds load from res://audio/sfx/<name>.wav|ogg (missing files are silently
## skipped, so placeholder audio can be replaced one file at a time).
## Music uses three synchronised stems (base / groove / rush) that fade in and
## out with the restaurant's state, plus separate closing and menu tracks.

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const POOL_SIZE := 28

var _streams := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _ui_players: Array[AudioStreamPlayer] = []
var _loops := {}
var _listener: AudioListener3D
var _stems := {}            ## name -> AudioStreamPlayer
var _stem_target := {}      ## name -> linear volume 0..1
var music_state: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 9.0
		p.max_db = 3.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.6
		add_child(p)
		_pool.push_back(p)
	for i in 6:
		var u := AudioStreamPlayer.new()
		u.bus = &"UI"
		add_child(u)
		_ui_players.push_back(u)
	_listener = AudioListener3D.new()
	add_child(_listener)
	for stem in ["stem_base", "stem_groove", "stem_rush", "music_closing", "music_menu"]:
		var mp := AudioStreamPlayer.new()
		mp.bus = &"Music"
		mp.volume_db = -80.0
		add_child(mp)
		_stems[stem] = mp
		_stem_target[stem] = 0.0
		var s := _stream(StringName(stem), MUSIC_DIR)
		if s:
			_make_loop(s)
			mp.stream = s


func _setup_buses() -> void:
	for bus in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, &"Master")


func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


func _stream(name: StringName, dir := SFX_DIR) -> AudioStream:
	var key := dir + String(name)
	if _streams.has(key):
		return _streams[key]
	var s: AudioStream = null
	for ext in [".ogg", ".wav"]:
		var path: String = dir + String(name) + ext
		if ResourceLoader.exists(path):
			s = load(path)
			break
	if s and String(name).ends_with("_loop"):
		_make_loop(s)
	_streams[key] = s
	return s


func _make_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)


# -----------------------------------------------------------------------------
# One-shots
# -----------------------------------------------------------------------------

## Plays a positional sound. On the authority it is mirrored to clients unless
## `local` is set.
func play_at(name: StringName, pos: Vector3, volume_db := 0.0, pitch := 1.0, local := false) -> void:
	if not local and Net.is_authority() and Net.is_online():
		Net.relay_sfx(name, pos, volume_db, pitch)
	var s := _stream(name)
	if s == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stop()
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()


func play_ui(name: StringName, volume_db := 0.0) -> void:
	var s := _stream(name)
	if s == null:
		return
	for u in _ui_players:
		if not u.playing:
			u.stream = s
			u.volume_db = volume_db
			u.play()
			return
	_ui_players[0].stream = s
	_ui_players[0].play()


# -----------------------------------------------------------------------------
# State-driven loops (run on every peer)
# -----------------------------------------------------------------------------

func loop(owner_node: Node3D, name: StringName, on: bool, volume_db := -4.0) -> void:
	if owner_node == null:
		return
	var key := "%d:%s" % [owner_node.get_instance_id(), name]
	var p: AudioStreamPlayer3D = _loops.get(key)
	if on:
		if p == null or not is_instance_valid(p):
			var s := _stream(name)
			if s == null:
				return
			p = AudioStreamPlayer3D.new()
			p.bus = &"SFX"
			p.stream = s
			p.unit_size = 7.0
			p.volume_db = volume_db
			p.panning_strength = 0.6
			owner_node.add_child(p)
			p.play()
			_loops[key] = p
		elif not p.playing:
			p.play()
	elif p != null:
		if is_instance_valid(p):
			p.queue_free()
		_loops.erase(key)


# -----------------------------------------------------------------------------
# Music
# -----------------------------------------------------------------------------

func set_music_state(state: StringName) -> void:
	if state == music_state:
		return
	var from := music_state
	music_state = state
	for k in _stem_target:
		_stem_target[k] = 0.0
	match state:
		&"prep":
			_stem_target["stem_base"] = 1.0
		&"service":
			_stem_target["stem_base"] = 1.0
			_stem_target["stem_groove"] = 1.0
		&"rush":
			_stem_target["stem_base"] = 1.0
			_stem_target["stem_groove"] = 1.0
			_stem_target["stem_rush"] = 1.0
		&"closing":
			_stem_target["music_closing"] = 1.0
		&"menu":
			_stem_target["music_menu"] = 1.0
	# Stems share a timeline: start them together if none is running.
	var stems_wanted: bool = _stem_target["stem_base"] > 0.0
	if stems_wanted:
		var running: bool = _stems["stem_base"].playing
		if not running:
			for k in ["stem_base", "stem_groove", "stem_rush"]:
				var mp: AudioStreamPlayer = _stems[k]
				if mp.stream:
					mp.play(0.0)
	for k in ["music_closing", "music_menu"]:
		var mp2: AudioStreamPlayer = _stems[k]
		if _stem_target[k] > 0.0 and not mp2.playing and mp2.stream:
			mp2.play()


func _process(delta: float) -> void:
	for k in _stems:
		var mp: AudioStreamPlayer = _stems[k]
		var cur := db_to_linear(mp.volume_db)
		var target: float = _stem_target[k]
		var speed := 0.6 if target > cur else 0.45
		cur = move_toward(cur, target, delta * speed)
		mp.volume_db = linear_to_db(maxf(cur, 0.0001))
		if cur <= 0.0005 and mp.playing and not k.begins_with("stem_"):
			mp.stop()
	if _stem_target["stem_base"] <= 0.0 and db_to_linear(_stems["stem_base"].volume_db) < 0.001:
		for k2 in ["stem_base", "stem_groove", "stem_rush"]:
			if _stems[k2].playing:
				_stems[k2].stop()
	# Keep the listener on the camera's focus so panning follows the diorama.
	var cam := get_viewport().get_camera_3d()
	if cam:
		var focus: Vector3 = cam.focus_point() if cam.has_method("focus_point") else cam.global_position
		_listener.global_position = focus + Vector3(0, 7.0, 4.0)
		_listener.global_basis = cam.global_basis
		if not _listener.is_current():
			_listener.make_current()


func stop_all_loops() -> void:
	for k in _loops:
		var p = _loops[k]
		if is_instance_valid(p):
			p.queue_free()
	_loops.clear()
