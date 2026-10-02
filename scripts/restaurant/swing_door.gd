class_name SwingDoor
extends Node3D
## Café-style double doors that swing away from whoever walks through.
## Purely visual (no collision) so they never trap anyone.

var half_height := 0.75
var color := Pal.DOOR_WOOD
var _left: Node3D
var _right: Node3D
var _angle := 0.0
var _vel := 0.0
var _check := 0.0
var _target := 0.0


func _ready() -> void:
	_left = _leaf(-0.47, 1.0)
	_right = _leaf(0.47, -1.0)


func _leaf(pivot_x: float, dir: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(pivot_x, 0, 0)
	add_child(pivot)
	var b := MeshBuilder.new()
	var w := 0.44
	var y0 := 0.3 if half_height < 0.7 else 0.35
	b.box(Vector3(dir * w * 0.5, y0 + half_height * 0.5, 0), Vector3(w, half_height, 0.05), color, 0.015)
	b.box(Vector3(dir * w * 0.5, y0 + half_height * 0.5, 0), Vector3(w - 0.1, half_height - 0.14, 0.065), color.lightened(0.12), 0.01)
	b.box(Vector3(dir * 0.02, y0 + half_height * 0.5, 0), Vector3(0.05, half_height + 0.04, 0.07), Pal.STEEL_DARK, 0.01)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Models.mat_main())
	pivot.add_child(mi)
	return pivot


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.08
		_target = 0.0
		var best := 1.1
		for a in get_tree().get_nodes_in_group(&"actors"):
			var n := a as Node3D
			if n == null:
				continue
			var local := to_local(n.global_position)
			var d := Vector2(local.x, local.z).length()
			if d < best and absf(local.x) < 0.7:
				best = d
				_target = -signf(local.z) * deg_to_rad(80.0)
	# Springy swing, sub-stepped so low frame rates can't blow it up.
	var remaining := minf(delta, 0.25)
	while remaining > 0.0:
		var dt := minf(remaining, 1.0 / 60.0)
		remaining -= dt
		var force := (_target - _angle) * 60.0 - _vel * 9.0
		_vel += force * dt
		_angle += _vel * dt
	_left.rotation.y = _angle
	_right.rotation.y = -_angle
