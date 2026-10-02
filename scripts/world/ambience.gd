class_name Ambience
extends Node3D
## Sound and life around the restaurant: a dining-room murmur that swells
## with the number of guests, and street traffic that picks up when the
## restaurant opens. Purely local presentation (every peer runs its own).

var world: GameWorld
var _crowd: AudioStreamPlayer3D
var _cars: Array[Node3D] = []
var _car_t := 2.0
var _rng := RandomNumberGenerator.new()

const CAR_COLORS := [Color("c96f5a"), Color("4f6d8f"), Color("e3b23c"), Color("6a9a9a"), Color("8c5a7a"), Color("e8e2d6")]


func _ready() -> void:
	_rng.randomize()
	_crowd = AudioStreamPlayer3D.new()
	_crowd.bus = &"SFX"
	_crowd.unit_size = 14.0
	_crowd.volume_db = -80.0
	var s: AudioStream = load("res://audio/sfx/crowd_loop.wav") if ResourceLoader.exists("res://audio/sfx/crowd_loop.wav") else null
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)
	_crowd.stream = s
	add_child(_crowd)


func _process(delta: float) -> void:
	if world == null or world.grid == null or world.day == null:
		return
	_update_crowd(delta)
	_update_traffic(delta)


func _update_crowd(delta: float) -> void:
	var guests := get_tree().get_nodes_in_group(&"customers").size()
	var dining := world.grid.cells_of_type(&"dining")
	if not dining.is_empty():
		var c := Vector3.ZERO
		for cell in dining:
			c += GameConst.cell_center(cell)
		_crowd.global_position = c / dining.size()
	var target_db := -80.0 if guests == 0 else lerpf(-20.0, -4.0, clampf(guests / 16.0, 0.0, 1.0))
	_crowd.volume_db = move_toward(_crowd.volume_db, target_db, delta * 20.0)
	if _crowd.stream and target_db > -79.0 and not _crowd.playing:
		_crowd.play()
	elif target_db <= -79.0 and _crowd.volume_db <= -79.0 and _crowd.playing:
		_crowd.stop()


func _update_traffic(delta: float) -> void:
	var road: Rect2 = Rect2()
	for g in world.layout_data().get("ground", []):
		if g["type"] == "road":
			var r: Array = g["rect"]
			road = Rect2(r[0], r[1], r[2], r[3])
	if road.size == Vector2.ZERO:
		return
	var busy := world.day.phase == GameConst.Phase.SERVICE
	_car_t -= delta
	if _car_t <= 0.0:
		_car_t = _rng.randf_range(2.5, 5.0) if busy else _rng.randf_range(8.0, 16.0)
		_spawn_car(road)
	for car in _cars.duplicate():
		var dir: float = car.get_meta(&"dir")
		car.position.x += dir * car.get_meta(&"speed") * delta
		if car.position.x < road.position.x - 6.0 or car.position.x > road.end.x + 6.0:
			_cars.erase(car)
			car.queue_free()


func _spawn_car(road: Rect2) -> void:
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	var car := Node3D.new()
	var m := MeshInstance3D.new()
	var b := MeshBuilder.new()
	var col: Color = CAR_COLORS[_rng.randi_range(0, CAR_COLORS.size() - 1)]
	b.block(Vector3(0, 0.25, 0), Vector3(1.6, 0.55, 3.2), col, 0.15)
	b.block(Vector3(0, 0.78, -0.15), Vector3(1.4, 0.48, 1.7), col.lightened(0.06), 0.14)
	b.box(Vector3(0, 1.02, -0.15), Vector3(1.42, 0.28, 1.5), Pal.WINDOW_GLASS.darkened(0.3), 0.08)
	for x in [-0.72, 0.72]:
		for z in [-1.05, 1.05]:
			b.push_at(Vector3(x, 0.3, z), 0.0, Vector3.ONE, 0.0, PI / 2.0)
			b.cyl(Vector3(0, -0.1, 0), 0.3, 0.2, Pal.RUBBER, 8, 0.04)
			b.pop()
	m.mesh = b.commit(Models.mat_main())
	car.add_child(m)
	var lane_z := road.get_center().y + (0.9 if dir > 0 else -0.9)
	car.position = Vector3(road.position.x - 5.0 if dir > 0 else road.end.x + 5.0, -0.02, lane_z)
	car.rotation.y = PI * 0.5 if dir > 0 else -PI * 0.5
	car.set_meta(&"dir", dir)
	car.set_meta(&"speed", _rng.randf_range(5.0, 8.0))
	add_child(car)
	_cars.push_back(car)
