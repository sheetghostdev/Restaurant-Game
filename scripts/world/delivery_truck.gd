class_name DeliveryTruck
extends Entity
## The delivery vehicle: drives up the alley, reverses to the dock with a
## beeping alarm, drops crates one by one, collects empties and leaves.

enum State { ARRIVING, UNLOADING, LEAVING }

var manager: DeliveryManager
var items: Array = []
var state := State.ARRIVING
var vehicle := "truck"
var _path: Array[Vector3] = []
var _i := 0
var _t := 0.0
var _beep := 0.0
var _model: Node3D
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _have := false
var _speed := 0.0


func get_kind() -> StringName:
	return &"truck"


func _ready() -> void:
	add_to_group(&"vehicles")
	_model = Node3D.new()
	add_child(_model)
	_build()


func _build() -> void:
	for c in _model.get_children():
		c.queue_free()
	if vehicle == "van":
		_model.add_child(Models.instance(&"van"))
		for x in [-0.75, 0.75]:
			for z in [-1.1, 1.1]:
				var w := Models.instance(&"truck_wheel")
				w.position = Vector3(x, 0.3, z)
				w.scale = Vector3.ONE * 0.9
				_model.add_child(w)
	else:
		_model.add_child(Models.instance(&"truck"))
		for x in [-0.9, 0.9]:
			for z in [-1.6, 1.8]:
				var w2 := Models.instance(&"truck_wheel")
				w2.position = Vector3(x, 0.32, z)
				_model.add_child(w2)


func start(path_pts: Array) -> void:
	_path.clear()
	for p in path_pts:
		_path.push_back(Vector3(float(p[0]), 0.0, float(p[1])))
	global_position = _path[0]
	_i = 1
	var d := _path[1] - _path[0]
	rotation.y = atan2(d.x, d.z)
	state = State.ARRIVING


func server_tick(delta: float) -> void:
	match state:
		State.ARRIVING:
			if _follow(delta, 4.5):
				state = State.UNLOADING
				_t = 0.6
				manager.collect_empties()
		State.UNLOADING:
			_t -= delta
			if _t <= 0.0:
				if items.is_empty():
					state = State.LEAVING
					_path.reverse()
					_i = 1
					Audio.play_at(&"truck_horn", global_position, -4.0)
				else:
					var it: Dictionary = items.pop_front()
					manager.drop_one(it)
					_t = 0.32
		State.LEAVING:
			if _follow(delta, 5.5, true):
				world.despawn(self)


func _follow(delta: float, speed: float, reverse_first := false) -> bool:
	if _i >= _path.size():
		return true
	var target := _path[_i]
	var to := target - global_position
	to.y = 0
	var dist := to.length()
	var last := _i == _path.size() - 1
	var want := speed if not last else clampf(dist * 1.5, 1.2, speed)
	_speed = move_toward(_speed, want, delta * 6.0)
	var step := _speed * delta
	if dist <= step:
		global_position = target
		_i += 1
		return _i >= _path.size()
	var dir := to / dist
	global_position += dir * step
	# The final approach is a reverse park: keep facing away from the dock.
	var facing_yaw := atan2(dir.x, dir.z)
	if last and state == State.ARRIVING:
		facing_yaw += PI
		_beep -= delta
		if _beep <= 0.0:
			_beep = 0.5
			Audio.play_at(&"truck_beep", global_position, -6.0)
	rotation.y = lerp_angle(rotation.y, facing_yaw, clampf(delta * 4.0, 0, 1))
	return false


func _process(delta: float) -> void:
	if not Net.is_authority() and _have:
		global_position = global_position.lerp(_target_pos, clampf(delta * 8.0, 0, 1))
		rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 8.0, 0, 1))
	Audio.loop(self, &"truck_engine_loop", true, -6.0)
	if _model:
		_model.position.y = sin(Time.get_ticks_msec() * 0.05) * 0.008


func get_motion() -> Array:
	return [snappedf(global_position.x, 0.01), snappedf(global_position.z, 0.01), snappedf(rotation.y, 0.01)]


func apply_motion(m: Array) -> void:
	_target_pos = Vector3(m[0], 0, m[1])
	_target_yaw = m[2]
	if not _have:
		global_position = _target_pos
		rotation.y = _target_yaw
	_have = true


func get_state() -> Dictionary:
	return {"v": vehicle}


func set_state(d: Dictionary) -> void:
	var v: String = d.get("v", vehicle)
	if v != vehicle:
		vehicle = v
		if _model:
			_build()
