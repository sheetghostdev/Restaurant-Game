class_name SlidingDoor
extends Node3D
## Train and airlock doors: two panels that slide apart when the doorway is
## open and close (with a collider) while the grid has that door type locked.

var door_type := "train_door"
var grid: RestaurantGrid
var color := Color("2f5d50")
var low := false
var _left: Node3D
var _right: Node3D
var _open := 1.0
var _body: StaticBody3D
var _shape: CollisionShape3D


func _ready() -> void:
	var h := 0.48 if low else 2.05
	_left = _panel(-1.0, h)
	_right = _panel(1.0, h)
	_body = StaticBody3D.new()
	_body.collision_layer = GameConst.L_WORLD
	_body.collision_mask = 0
	_shape = CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, 2.0, 0.2)
	_shape.shape = sh
	_shape.position = Vector3(0, 1.0, 0)
	_body.add_child(_shape)
	add_child(_body)
	_open = 0.0 if _locked() else 1.0
	_apply()


func _panel(side: float, h: float) -> Node3D:
	var pivot := Node3D.new()
	add_child(pivot)
	var b := MeshBuilder.new()
	b.block(Vector3(side * 0.24, 0.0, 0), Vector3(0.46, h, 0.06), color, 0.012)
	if not low:
		# A small window in each panel.
		b.block(Vector3(side * 0.24, 1.15, 0), Vector3(0.24, 0.5, 0.075), Color("cfeaf2"), 0.01)
	b.block(Vector3(side * 0.03, 0.0, 0), Vector3(0.04, h, 0.075), Pal.STEEL_DARK, 0.008)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Models.mat_main())
	pivot.add_child(mi)
	pivot.set_meta(&"side", side)
	return pivot


func _locked() -> bool:
	return grid != null and grid.locked.has(door_type)


func _process(delta: float) -> void:
	var want := 0.0 if _locked() else 1.0
	if absf(_open - want) < 0.001:
		return
	_open = move_toward(_open, want, delta * 1.6)
	_apply()


func _apply() -> void:
	for p in [_left, _right]:
		var side: float = p.get_meta(&"side")
		p.position.x = side * 0.42 * _open
		p.visible = _open < 0.98   # tucked into the wall when open
	if _shape:
		_shape.disabled = _open > 0.5
